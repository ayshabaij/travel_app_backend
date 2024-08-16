require 'sinatra'
require 'sinatra/cors'
require 'google_maps_service'
require 'sqlite3'
require 'json'
require 'date'

API_KEY = '' # Add your Google Maps API key here
set :port, 4568 

# Configure CORS
set :allow_origin, "http://localhost:3000"  # Change to the origin of your Rails app
set :allow_methods, "GET,POST,OPTIONS"
set :allow_headers, "content-type,if-modified-since"
set :expose_headers, "location,link"

# Handle CORS preflight requests
options '*' do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET,POST,OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'content-type,if-modified-since'
  200
end

def initialize_gmaps(api_key)
  if api_key.nil? || api_key.empty?
    puts "Invalid or missing API key."
    nil
  else
    puts "API Key found: #{api_key}"
    GoogleMapsService::Client.new(key: api_key)
  end
end

# Initialize the Google Maps client
gmaps = initialize_gmaps(API_KEY)

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
  user_data = db.execute("SELECT hobbies, dob, dietary_restrictions, accessibilities FROM user_data WHERE user_id = ?", [user_id]).first

  if user_data
    hobbies = user_data[0].split(',')
    date_of_birth = user_data[1]
    dietary_restrictions = user_data[2].split(',')
    accessibilities = user_data[3].split(',')

    # Create User object with all the gathered information
    user = User.new(hobbies, date_of_birth, dietary_restrictions, accessibilities, [start_date, end_date], budget, address)

    if validate_dietary_restrictions_and_accessibilities(user.dietary_restrictions, user.accessibilities)
      user.hobbies = fetch_hobbies_from_db(user.hobbies)

      if user.hobbies && user.current_location && user.budget
        prompt = generate_prompt(user)
        { status: 'success', prompt: prompt }.to_json
      else
        { status: 'failure', message: 'Could not generate prompt due to missing or invalid data.' }.to_json
      end
    else
      { status: 'failure', message: 'Validation of dietary restrictions or accessibilities failed.' }.to_json
    end
  else
    { status: 'failure', message: "User with ID #{user_id} not found." }.to_json
  end
end

# Method to get location from Google Maps API
def get_location_from_google_maps(gmaps, address)
  if gmaps.nil?
    return address # If gmaps is nil, return the address without validation
  end

  begin
    geocode_result = gmaps.geocode(address)
    if geocode_result.any? && geocode_result[0][:formatted_address].include?('South Korea')
      puts geocode_result[0][:formatted_address]
      return geocode_result[0][:formatted_address]
    else
      puts 'The address is not in South Korea. Please provide a valid address in South Korea.'
    end
  rescue StandardError => e
    puts "Error occurred while trying to geocode the address: #{e.message}"
  end
  nil
end

# Method to fetch hobbies from database
def fetch_hobbies_from_db(hobby_list)
  db = SQLite3::Database.new 'hobby_database.db'
  hobbies = {}
  missing_hobbies = []

  hobby_list.each do |hobby|
    rows = db.execute('SELECT l.location FROM hobbies h JOIN locations l ON h.id = l.hobby_id WHERE h.name = ?', [hobby])
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
                                'Dairy-free', 'Lactose intolerant', 'Shellfish allergy', 'Soy allergy', 'Egg allergy', 'Seafood allergy', 'Low-sodium', 'Low-carb', 'Low-fat', 'Diabetic', 'No pork', 'Pescatarian', 'Paleo', 'Keto', 'FODMAP', 'Organic only', 'Peanut allergy', 'Citrus allergy', 'Sulfite allergy', 'Fructose intolerance', 'MSG sensitivity', 'Raw food diet', 'Nightshade allergy']

  valid_accessibilities = ['None', 'Wheelchair user', 'Visual impairment', 'Hearing impairment', 'Cognitive disability',
                           'Autism', 'Dyslexia', 'ADHD', 'Mobility impairment', 'Chronic pain', 'Mental health condition', 'Speech impairment', 'Chronic illness', 'Epilepsy', "Alzheimer\\'s disease", "Parkinson\\'s disease", 'Down syndrome', 'Spinal cord injury', 'Cerebral palsy', 'Muscular dystrophy', 'Multiple sclerosis']

  invalid_dietary = dietary_restrictions.reject { |r| valid_dietary_restrictions.include?(r) }
  invalid_accessibilities = accessibilities.reject { |d| valid_accessibilities.include?(d) }

  unless invalid_dietary.empty?
    puts "Invalid dietary restrictions: #{invalid_dietary.join(', ')}. Please provide valid dietary restrictions."
    return false
  end

  unless invalid_accessibilities.empty?
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

  if user.dietary_restrictions
    clause << "The user has dietary restrictions: #{user.dietary_restrictions.join(', ')}. Recommend only places that meet these criteria for food and activities."
  end

  if user.accessibilities
    clause << "The user has accessibilities: #{user.accessibilities.join(', ')}. Ensure that recommended places are accessible."
  end

  if user.budget
    clause << "The user has a budget of #{user.budget} KRW. Make sure the total costs of activities shown do not go above this."
  end

  clause << 'Only recommend places in South Korea.'

  hobbies_str = user.hobbies.map { |hobby, details| "#{hobby}: #{details}" }.join(', ')
  
  prompt = <<~PROMPT
    **User Information:**

    - **Hobbies:** 
      - #{hobbies_str.split(', ').join("\n      - ")}

    - **Dietary Restrictions:** 
      - #{user.dietary_restrictions.join("\n      - ")}

    - **Accessibilities:** #{user.accessibilities.any? ? user.accessibilities.join(', ') : 'None'}

    **Travel Information:**

    - **Current Location:** #{user.current_location}
    - **Travel Dates:** #{user.travel_dates[0]} to #{user.travel_dates[1]}
    - **Budget:** #{user.budget} KRW

    **Request:**

    Recommend a minimum of 10 places near the user’s current location in Seoul, South Korea. Ensure that the recommendations align with the user's hobbies and consider any recent headlines or trends related to the area. The user has the following dietary restrictions: #{user.dietary_restrictions.join(', ')}; therefore, recommend only places that meet these criteria for food and activities. Additionally, ensure that all recommended places are accessible, as the user has #{user.accessibilities.any? ? user.accessibilities.join(', ') : 'no specific accessibility requirements'}. The user has a budget of #{user.budget} KRW, so make sure the total costs of the recommended activities do not exceed this amount.
  PROMPT

  prompt.gsub(/\s+/, ' ').strip  # Replace multiple spaces with a single space and remove leading/trailing spaces
end
