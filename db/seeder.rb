require 'sqlite3'

db = SQLite3::Database.new("databas.db")


def seed!(db)
  puts "Using db file: db/databas.db"
  puts "🧹 Dropping old tables..."
  drop_tables(db)
  puts "🧱 Creating tables..."
  create_tables(db)
  puts "🍎 Populating tables..."
  populate_tables(db)
  puts "✅ Done seeding the database!"
end

def drop_tables(db)
  db.execute('DROP TABLE IF EXISTS adventurename')
  db.execute('DROP TABLE IF EXISTS user')
  db.execute('DROP TABLE IF EXISTS arooms')
  db.execute('DROP TABLE IF EXISTS actions')
end


def create_tables(db)
  db.execute('CREATE TABLE adventurename (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              pic_link TEXT,
              name TEXT NOT NULL, 
              description TEXT)')
  db.execute('CREATE TABLE user (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL, 
              pwd_digest TEXT NOT NULL)')
  db.execute('CREATE TABLE arooms (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL, 
              description TEXT)')
  db.execute('CREATE TABLE actions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL, 
              description TEXT)')
  
end

def populate_tables(db)
  db.execute('INSERT INTO adventurename (name, description) VALUES ("Äventyr 1", "jsdfjnkvcxbjifvbnjkvcxjb")')
  db.execute('INSERT INTO adventurename (name, description) VALUES ("Äventyr 2", "EFDVÖKOJVCDHPJFVDHJKDCVNJK")')
  db.execute('INSERT INTO adventurename (name, description) VALUES ("Äventyr 3", "jixidfivnj3984ieoppdoododjvglkjcvjkcxk")')
end


seed!(db)





