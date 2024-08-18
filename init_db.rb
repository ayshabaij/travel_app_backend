# frozen_string_literal: true

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

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS locations (
    id INTEGER PRIMARY KEY,
    hobby_id INTEGER,
    location TEXT,
    FOREIGN KEY(hobby_id) REFERENCES hobbies(id)
  );
SQL

# Insert test data into the tables (only if no data exists)
DB.execute <<-SQL
  INSERT INTO hobbies (name)
  SELECT 'Swimming' WHERE NOT EXISTS (SELECT 1 FROM hobbies WHERE name = 'Swimming');
SQL

DB.execute <<-SQL
  INSERT INTO hobbies (name)
  SELECT 'Running' WHERE NOT EXISTS (SELECT 1 FROM hobbies WHERE name = 'Running');
SQL

DB.execute <<-SQL
  INSERT INTO hobbies (name)
  SELECT 'Art' WHERE NOT EXISTS (SELECT 1 FROM hobbies WHERE name = 'Art');
SQL

DB.execute <<-SQL
  INSERT INTO locations (hobby_id, location)
  SELECT (SELECT id FROM hobbies WHERE name = 'Swimming'), 'Seoul Olympic Park' WHERE NOT EXISTS#{' '}
  (SELECT 1 FROM locations WHERE hobby_id = (SELECT id FROM hobbies WHERE name = 'Swimming') AND location = 'Seoul Olympic Park');
SQL

DB.execute <<-SQL
  INSERT INTO locations (hobby_id, location)
  SELECT (SELECT id FROM hobbies WHERE name = 'Running'), 'Han River Park' WHERE NOT EXISTS#{' '}
  (SELECT 1 FROM locations WHERE hobby_id = (SELECT id FROM hobbies WHERE name = 'Running') AND location = 'Han River Park');
SQL

puts 'Tables and test data created successfully.'
