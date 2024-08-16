require 'sqlite3'

# Connect to the database
DB = SQLite3::Database.new 'reception_database.db'

# Create tables if they don't exist
DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS hobbies (
    id INTEGER PRIMARY KEY,
    name TEXT
  );
SQL

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS dietary_restrictions (
    id INTEGER PRIMARY KEY,
    name TEXT
  );
SQL

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS accessibilities (
    id INTEGER PRIMARY KEY,
    name TEXT
  );
SQL

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS user_data (
    id INTEGER PRIMARY KEY,
    user_id INTEGER,  -- Add the user_id column here
    dob TEXT,
    hobbies TEXT,
    dietary_restrictions TEXT,
    accessibilities TEXT
  );
SQL

puts "Tables created successfully."
