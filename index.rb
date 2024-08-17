# frozen_string_literal: true

require 'sinatra'
require 'sinatra/cors'
require 'geocoder'
require 'sqlite3'
require 'json'
require 'date'
require 'net/http'
require 'uri'

API_KEY = '' # Add your Google API key here
set :port, 4568

# Configure Geocoder with your API key
Geocoder.configure(
  lookup: :google,
  api_key: API_KEY,
  use_https: true
)

# Configure CORS
set :allow_origin, 'http://localhost:3000' # Change to the origin of your Rails app
set :allow_methods, 'GET,POST,OPTIONS'
set :allow_headers, 'content-type,if-modified-since'
set :expose_headers, 'location,link'

# Handle CORS preflight requests
options '*' do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET,POST,OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'content-type,if-modified-since'
  200
end

class User
  attr_accessor :hobbies, :date_of_birth, :dietary_restrictions, :accessibilities,
                :travel_dates, :budget, :current_location

  def initialize(hobbies, date_of_birth, dietary_restrictions = nil,
                 accessibilities = nil, travel_dates = nil, budget = nil, current_location = nil)
    @hobbies = hobbies
    @date_of_birth = date_of_birth
    @dietary_restrictions = dietary_restrictions
    @accessibilities = accessibilities
    @travel_dates = travel_dates
    @current_location = current_location
    @budget = budget
  end
end

# Method to get location from Geocoder and validate it
def get_location_from_geocoder(address)
  puts "Starting geocode for address: #{address.inspect}"

  result = Geocoder.search(address).first
  if result && result.address.include?('South Korea')
    puts "Geocode successful: #{result.address}"
    return result.address
  else
    puts 'The address is not in South Korea. Please provide a valid address in South Korea.'
    return nil
  end
rescue StandardError => e
  puts "Error occurred while trying to geocode the address: #{e.message}"
  return nil
end

post '/receive_trip_data' do
  content_type :json

  # Get data from the POST request
  request_data = JSON.parse(request.body.read)
  user_id = request_data['user_id']
  start_date = request_data['start_date']
  end_date = request_data['end_date']
  address = request_data['address']
  budget = request_data['budget']

  # Fetch user data from the user_data table in reception_database.db
  db = SQLite3::Database.new 'reception_database.db'
  user_data = db.execute('SELECT hobbies, dob, dietary_restrictions, accessibilities FROM user_data WHERE user_id = ?',
                         [user_id]).first

  if user_data
    hobbies = user_data[0].split(',')
    date_of_birth = user_data[1]
    dietary_restrictions = user_data[2].split(',')
    accessibilities = user_data[3].split(',')

    # Create User object with all the gathered information
    user = User.new(hobbies, date_of_birth, dietary_restrictions, accessibilities, [start_date, end_date], budget, address)

    # Validate the user's location
    validated_location = get_location_from_geocoder(user.current_location)

    if validated_location.nil?
      { status: 'failure', message: 'Location validation failed. The location must be in South Korea.' }.to_json
    else
      user.current_location = validated_location

      if validate_dietary_restrictions_and_accessibilities(user.dietary_restrictions, user.accessibilities)
        user.hobbies = fetch_hobbies_from_db(user.hobbies)

        if user.hobbies && user.current_location && user.budget
          prompt = generate_prompt(user)
          if prompt
            { status: 'success', prompt: prompt }.to_json
          else
            { status: 'failure', message: 'Could not generate prompt due to missing or invalid data.' }.to_json
          end
        else
          { status: 'failure', message: 'Could not generate prompt due to missing or invalid data.' }.to_json
        end
      else
        { status: 'failure', message: 'Validation of dietary restrictions or accessibilities failed.' }.to_json
      end
    end
  else
    { status: 'failure', message: "User with ID #{user_id} not found." }.to_json
  end
end

# Method to fetch hobbies from database
def fetch_hobbies_from_db(hobby_list)
  db = SQLite3::Database.new 'hobbies.db'
  hobbies = {}
  missing_hobbies = []

  hobby_list.each do |hobby|
    rows = db.execute('SELECT l.location FROM hobbies h JOIN locations l ON h.id = l.hobby_id WHERE h.name = ?',
                      [hobby])
    if rows.any?
      hobbies[hobby] = rows.map { |row| row[0] }.join(', ')
    else
      missing_hobbies << hobby
    end
  end

  if missing_hobbies.any?
    puts "The following hobbies do not exist in the database: #{missing_hobbies.join(', ')}"
    return nil
  end

  hobbies
rescue SQLite3::Exception => e
  puts "An error occurred while accessing the database: #{e.message}"
  nil
ensure
  db&.close
end

# Method to validate dietary restrictions and accessibilities
def validate_dietary_restrictions_and_accessibilities(dietary_restrictions, accessibilities)
  valid_dietary_restrictions = ['None', 'Halal', 'Kosher', 'Vegan', 'Vegetarian', 'Nut allergy', 'Gluten-free',
                                'Dairy-free', 'Lactose intolerant', 'Shellfish allergy', 'Soy allergy', 'Egg allergy',
                                'Seafood allergy', 'Low-sodium', 'Low-carb', 'Low-fat', 'Diabetic', 'No pork',
                                'Pescatarian', 'Paleo', 'Keto', 'FODMAP', 'Organic only', 'Peanut allergy',
                                'Citrus allergy', 'Sulfite allergy', 'Fructose intolerance', 'MSG sensitivity',
                                'Raw food diet', 'Nightshade allergy']

  valid_accessibilities = ['None', 'Wheelchair user', 'Visual impairment', 'Hearing impairment', 'Cognitive disability',
                           'Autism', 'Dyslexia', 'ADHD', 'Mobility impairment', 'Chronic pain', 'Mental health condition',
                           'Speech impairment', 'Chronic illness', 'Epilepsy', "Alzheimer's disease",
                           "Parkinson's disease", 'Down syndrome', 'Spinal cord injury', 'Cerebral palsy',
                           'Muscular dystrophy', 'Multiple sclerosis']

  invalid_dietary = dietary_restrictions.reject { |r| valid_dietary_restrictions.include?(r) }
  invalid_accessibilities = accessibilities.reject { |d| valid_accessibilities.include?(d) }

  if invalid_dietary.any?
    puts "Invalid dietary restrictions: #{invalid_dietary.join(', ')}. Please provide valid dietary restrictions."
    return false
  end

  if invalid_accessibilities.any?
    puts "Invalid accessibilities: #{invalid_accessibilities.join(', ')}. Please provide valid accessibilities."
    return false
  end

  true
end

# Method to generate prompt for the user
def generate_prompt(user)
  clause = []

  if user.date_of_birth == Date.today.strftime('%d/%m/%Y') # Updated comparison to "dd/mm/yyyy"
    clause << "It's the user's birthday today, so add an appropriate birthday venue activity."
  end

  if user.dietary_restrictions.any?
    clause << "The user has dietary restrictions: #{user.dietary_restrictions.join(', ')}. Recommend only places that meet these criteria for food and activities."
  end

  if user.accessibilities.any?
    clause << "The user has accessibilities: #{user.accessibilities.join(', ')}. Ensure that recommended places are accessible."
  end

  if user.budget
    clause << "The user has a budget of #{user.budget} KRW. Make sure the total costs of activities shown do not go above this."
  end

  clause << 'Only recommend places in South Korea.'

  hobbies_str = user.hobbies.map { |hobby, details| "#{hobby}: #{details}" }.join(', ')

  prompt = <<~PROMPT
    User Information:
    - Hobbies: #{hobbies_str}
    - Dietary Restrictions: #{user.dietary_restrictions.join(', ') if user.dietary_restrictions.any?}
    - Accessibilities: #{user.accessibilities.join(', ') if user.accessibilities.any?}

    Travel Information:
    - Current Location: #{user.current_location}, South Korea
    - Travel Dates: #{user.travel_dates[0]} to #{user.travel_dates[1]}
    - Budget: #{user.budget} KRW

    Request:
    Recommend a minimum of 10 places for the user near #{user.current_location} to visit.
    Consider the user's hobbies and recent headlines or trends from the internet related to the area, ensure recommendations are age-appropriate to the user's age.
    #{clause.join(' ')}
  PROMPT

  adapter_id = 'AI-travel-app-model/2'
  api_token = '' # Replace with your API token

  url = URI('https://serving.app.predibase.com/7ea6d0/deployments/v2/llms/solar-1-mini-chat-240612/generate')

  payload = {
    'inputs' => prompt,
    'parameters' => {
      'adapter_id' => adapter_id,
      'adapter_source' => 'pbase',
      'max_new_tokens' => 1500, # Increased limit to generate more detailed output
      'temperature' => 0.6 # Adjusted temperature for more focused responses
    }
  }.to_json

  headers = {
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{api_token}"
  }

  begin
    response = Net::HTTP.post(url, payload, headers)
    json_response = JSON.parse(response.body)
    json_response['generated_text'] || 'No generated text found in response'
  rescue JSON::ParserError
    puts 'Failed to decode JSON from the response'
    nil
  end
end
