# frozen_string_literal: true

require 'sinatra'
require 'sinatra/cors'
require 'sqlite3'
require 'json'

# Connect to the database
DB = SQLite3::Database.new 'reception_database.db'

# Configure the Sinatra application to run on port 4567
set :port, 4567

# Configure CORS
set :allow_origin, '*'
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

# Endpoint to receive data from the front-end
post '/receive_data' do
  response.headers['Access-Control-Allow-Origin'] = '*'

  begin
    request_payload = JSON.parse(request.body.read)
  rescue JSON::ParserError => e
    logger.error "Failed to parse JSON: #{e.message}"
    halt 400, { error: 'Invalid JSON' }.to_json
  end
  user_id = request_payload['user_id']
  dob = request_payload['dob']
  hobbies = request_payload['hobbies']
  dietary_restrictions = request_payload['dietary_restrictions']
  accessibilities = request_payload['accessibilities']

  # Retrieve the existing record for the user
  existing_user = DB.execute(
    'SELECT id, dob, hobbies, dietary_restrictions, accessibilities FROM user_data WHERE user_id = ?', [user_id]
  ).first

  if existing_user
    # Update only the provided fields while preserving the existing data for others
    existing_dob = dob || existing_user[1]
    existing_hobbies = hobbies ? hobbies.join(',') : existing_user[2]
    existing_dietary_restrictions = dietary_restrictions ? dietary_restrictions.join(',') : existing_user[3]
    existing_accessibilities = accessibilities ? accessibilities.join(',') : existing_user[4]

    DB.execute('UPDATE user_data SET dob = ?, hobbies = ?, dietary_restrictions = ?, accessibilities = ? WHERE user_id = ?',
               [existing_dob, existing_hobbies, existing_dietary_restrictions, existing_accessibilities, user_id])
  else
    # Insert a new record if the user doesn't exist
    DB.execute('INSERT INTO user_data (user_id, dob, hobbies, dietary_restrictions, accessibilities) VALUES (?, ?, ?, ?, ?)',
               [user_id, dob, hobbies ? hobbies.join(',') : '',
                dietary_restrictions ? dietary_restrictions.join(',') : '', accessibilities ? accessibilities.join(',') : ''])
  end

  content_type :json
  { status: 'success', message: 'Data received and stored successfully' }.to_json
end
