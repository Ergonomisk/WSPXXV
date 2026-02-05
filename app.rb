require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

get ('/home') 
  db=SQLite3::Database.new('db/todos.db')
  db.results_as_hash = true
  @databastodos = db.execute("SELECT * FROM todos WHERE done = 0")
  @databastodosdone = db.execute("SELECT * FROM todos WHERE done = 1")
  p @databastodos
  slim(:"index")

end