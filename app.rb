require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'


get('/') do
  
  slim(:loggin)

end

get('/home') do
  db=SQLite3::Database.new('db/databas.db')
  db.results_as_hash = true
  @databasadventurename = db.execute("SELECT * FROM adventurename")
  slim(:"index")
end

get('/adventure/:id') do
  db=SQLite3::Database.new('db/databas.db')
  db.results_as_hash = true
  id = params[:id].to_i

  @special_adventure = db.execute("SELECT * FROM adventurename WHERE id = ?", id).first
  @rooms = db.execute("SELECT * FROM arooms WHERE adventure_id = ?", id)

  # Get actions for all rooms in this adventure
  @actions_by_room = {}
  @rooms.each do |room|
    @actions_by_room[room["id"]] = db.execute("SELECT * FROM actions WHERE room_id = ?", room["id"])
  end

  slim(:'adventure')
end


post('/login')do
  name = params["name"]
  pwd = params["pwd"]
  db = SQLite3::Database.new("db/databas.db")
  db.results_as_hash = true
  result=db.execute("SELECT id,pwd_digest FROM user WHERE name=?", name)
  if result.empty?
    redirect('/error')
  end
  user_id = (result.first["id"])
  pwd_digest =result.first["pwd_digest"]
  if BCrypt::Password.new(pwd_digest) == pwd
    session[:user_id] = user_id
    redirect('/home')
  else
    redirect('/')
  end

end


post('/user') do
  name = params["name"]
  pwd = params["pwd"]
  pwd_confirm = params["pwd_confirm"]

  if pwd.length < 3
    redirect('/?error=Lösenordet+måste+vara+minst+3+tecken')
  end

  db = SQLite3::Database.new("db/databas.db")
  result=db.execute("SELECT id FROM user WHERE name=?", name)

  if result.empty?
    if pwd == pwd_confirm
      pwd_digest=BCrypt::Password.create(pwd)
      db.execute("INSERT INTO user(name, pwd_digest) VALUES(?,?)",[name, pwd_digest])
      redirect('/home')
    else
      redirect('/?error=Lösenorden+matchar+inte')
    end
  else
    redirect('/?error=Användarnamnet+är+redan+taget')
  end

end