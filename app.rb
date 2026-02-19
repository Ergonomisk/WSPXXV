require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

get ('/home') do
  db=SQLite3::Database.new('db/databas.db')
  db.results_as_hash = true
  @databasadventurename = db.execute("SELECT * FROM adventurename")
  p @databasadventurename
  slim(:"index")

end

get ('/adventure/:id') do
  db=SQLite3::Database.new('db/databas.db')
  db.results_as_hash = true
  id = params[:id].to_i
  @special_adventure = db.execute("SELECT * FROM adventurename WHERE id = ?",id).first
  slim(:'adventure')
  

end
