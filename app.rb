# frozen_string_literal: true

require 'sinatra'
require 'slim'
require 'sinatra/reloader'
require_relative 'model'

enable :sessions
set :session_secret, 'rollspelsdax_super_hemlig_nyckel_som_ar_tillrackligt_lang_for_rack_session_kryptering'

# ────────────────────────────────────────
# Helpers
# ────────────────────────────────────────
helpers do
  # Kontrollerar om en användare är inloggad via sessionen.
  #
  # @return [Boolean] true om user_id finns i sessionen, annars false
  def logged_in?
    !session[:user_id].nil?
  end

  # Kontrollerar om den inloggade användaren har adminbehörighet.
  #
  # @return [Boolean] true om is_admin är satt i sessionen, annars false
  def admin?
    session[:is_admin] == true
  end

  # Returnerar ett läsbart visningsnamn med emoji för ett föremål
  # baserat på dess interna nyckel. Om nyckeln saknas i tabellen
  # returneras nyckeln oförändrad som fallback.
  #
  # @param key [String] föremålets interna nyckel, t.ex. 'sword' eller 'gold_coin'
  # @return [String] visningsnamn med emoji, eller nyckeln om den inte finns i tabellen
  def item_name(key)
    names = {
      'sword'        => '🗡️ Rostigt svärd',
      'health_potion'=> '🧪 Hälsodryck',
      'gold_coin'    => '🪙 Guldmynt',
      'key'          => '🗝️ Nyckel',
      'magic_sword'  => '✨ Magiskt svärd',
      'rusty_key'    => '🗝️ Rostig nyckel',
      'oil'          => '🫙 Olja',
      'castle_sword' => '⚔️ Slottssvärd',
      'wand'         => '🪄 Besvärjelsepinne',
      'shield_spell' => '🛡️ Skyddszauber',
      'victory'      => '🏆 Seger'
    }
    names[key] || key
  end
end

# ────────────────────────────────────────
# Before-filter: inloggning
# ────────────────────────────────────────

# Routes som är tillgängliga utan inloggning.
GUEST_ROUTES = ['/', '/login', '/user'].freeze

# Globalt before-filter som körs före varje route.
# Omdirigerar till startsidan om användaren inte är inloggad
# och försöker nå en skyddad route.
#
# @return [void]
before do
  unless GUEST_ROUTES.include?(request.path_info) || logged_in?
    redirect '/'
  end
end

# ────────────────────────────────────────
# Before-filter: admin
# ────────────────────────────────────────

# Before-filter som skyddar alla routes under /admin.
# Omdirigerar till /home om den inloggade användaren inte är admin.
#
# @return [void]
before '/admin*' do
  redirect '/home' unless admin?
end

# ────────────────────────────────────────
# Inloggning / Registrering
# ────────────────────────────────────────

# Before-filter för routen '/'.
# Lägger till en kort fördröjning för att motverka brute-force-attacker.
#
# @return [void]
before('/') { sleep(0.5) }

# Visar inloggnings- och registreringssidan.
#
# @return [String] renderad HTML via Slim-mallen :loggin
get '/' do
  slim :loggin
end

# Hanterar inloggningsformuläret.
# Autentiserar användaren och sparar id samt adminbehörighet i sessionen.
# Omdirigerar till /home vid lyckad inloggning, annars tillbaka till /
# med ett felmeddelande i query-strängen.
#
# @param name [String] formulärparameter – användarnamnet
# @param pwd  [String] formulärparameter – lösenordet i klartext
# @return [void]
post '/login' do
  user = User.authenticate(params['name'], params['pwd'])
  if user.nil?
    redirect('/?error=Fel+användarnamn+eller+lösenord')
  else
    session[:user_id]  = user['id']
    session[:is_admin] = user['is_admin'] == 1
    redirect('/home')
  end
end

# Hanterar registreringsformuläret.
# Validerar indata, skapar en ny användare och loggar in direkt.
# Omdirigerar till /home vid lyckat skapande, annars tillbaka till /
# med ett felmeddelande i query-strängen.
#
# @param name        [String] formulärparameter – önskat användarnamn
# @param pwd         [String] formulärparameter – lösenord i klartext
# @param pwd_confirm [String] formulärparameter – lösenordsbekräftelse
# @return [void]
post '/user' do
  name        = params['name'].to_s.strip
  pwd         = params['pwd'].to_s
  pwd_confirm = params['pwd_confirm'].to_s

  if name.empty?
    redirect('/?error=Användarnamnet+får+inte+vara+tomt')
  elsif pwd.length < 3
    redirect('/?error=Lösenordet+måste+vara+minst+3+tecken')
  elsif pwd != pwd_confirm
    redirect('/?error=Lösenorden+matchar+inte')
  elsif User.exists?(name)
    redirect('/?error=Användarnamnet+är+redan+taget')
  else
    User.create(name, pwd)
    user = User.authenticate(name, pwd)
    session[:user_id]  = user['id']
    session[:is_admin] = user['is_admin'] == 1
    redirect('/home')
  end
end

# Loggar ut användaren genom att rensa hela sessionen
# och omdirigera till startsidan.
#
# @return [void]
get '/logout' do
  session.clear
  redirect '/'
end

# ────────────────────────────────────────
# Hem: lista alla äventyr
# ────────────────────────────────────────

# Visar startsidan med alla tillgängliga äventyr.
# Stöder fritextsökning via query-parametern 'q'.
# Kräver att användaren är inloggad (hanteras av globalt before-filter).
#
# @param q [String, nil] valfri query-parameter för fritextsökning på äventyrsnamn
# @return [String] renderad HTML via Slim-mallen :index
get '/home' do
  q = params[:q]
  @adventures = (q && !q.empty?) ? Adventure.search(q) : Adventure.all
  slim :index
end

# ────────────────────────────────────────
# Äventyret
# ────────────────────────────────────────

# Visar äventyrssidan för ett givet äventyr.
# Om spelaren saknar en aktiv omgång visas startsidan för äventyret.
# Annars laddas aktuellt rum, tillgängliga handlingar, inventory och logg.
# Returnerar 404 om äventyret inte hittas.
# Kräver att användaren är inloggad (hanteras av globalt before-filter).
#
# @param id [String] route-parameter – äventyrets databas-id
# @return [String] renderad HTML via Slim-mallen :adventure_start eller :adventure
get '/adventure/:id' do
  @adventure = Adventure.find(params[:id])
  halt 404, "Äventyret hittades inte" unless @adventure

  @run = PlayerRun.find_active(session[:user_id], @adventure['id'])

  if @run.nil?
    slim :adventure_start
  else
    @room        = Room.find(@run['current_room_id'])
    @total_rooms = Room.count_in_adventure(@adventure['id'])

    all_actions = Action.for_room(@room['id'])
    used_ids    = RunLog.used_action_ids(@run['id'])

    # Filtrera bort handlingar som redan utförts eller kräver föremål
    # som spelaren inte bär på.
    @available_actions = all_actions.select do |action|
      next false if used_ids.include?(action['id'])
      req = action['requires_item']
      req.nil? || req.empty? || Inventory.has?(@run['id'], req)
    end

    @inventory = Inventory.for_run(@run['id'])
    @log       = RunLog.recent(@run['id'])

    slim :adventure
  end
end

# ────────────────────────────────────────
# Starta / starta om en spelomgång
# ────────────────────────────────────────

# Startar (eller startar om) en spelomgång för det givna äventyret.
# Eventuella tidigare omgångar raderas först — ON DELETE CASCADE tar
# automatiskt bort kopplade inventory_items och run_log-poster.
# Skapar sedan en ny omgång med start i äventyrets första rum.
# Kräver att användaren är inloggad (hanteras av globalt before-filter).
#
# @param id [String] route-parameter – äventyrets databas-id
# @return [void]
post '/adventure/:id/start' do
  adventure_id = params[:id].to_i
  PlayerRun.delete_for(session[:user_id], adventure_id)
  first_room = Room.first_in_adventure(adventure_id)
  PlayerRun.create(session[:user_id], adventure_id, first_room['id'])
  redirect "/adventure/#{adventure_id}"
end

# ────────────────────────────────────────
# Utför en handling
# ────────────────────────────────────────

# Utför en vald handling i det aktuella rummet.
# Hanterar inventory-förändringar (lägger till och tar bort föremål),
# loggar handlingen och flyttar spelaren till nästa rum om handlingen
# är märkt med moves_to_next. Avslutar omgången om inget nästa rum finns.
#
# Returnerar 400 om ingen aktiv omgång finns, handlingen tillhör fel rum,
# eller spelaren saknar ett krävt föremål.
# Returnerar 404 om handlingen inte hittas.
# Kräver att användaren är inloggad (hanteras av globalt before-filter).
#
# @param id        [String] route-parameter – äventyrets databas-id
# @param action_id [String] route-parameter – handlingens databas-id
# @return [void]
post '/adventure/:id/action/:action_id' do
  adventure_id = params[:id].to_i
  action_id    = params[:action_id].to_i

  @run = PlayerRun.find_active(session[:user_id], adventure_id)
  halt 400, "Inget aktivt spel" unless @run

  action = Action.find(action_id)
  halt 404, "Handlingen hittades inte"  unless action
  halt 400, "Fel rum"                   unless action['room_id'] == @run['current_room_id']

  req = action['requires_item']
  if req && !req.empty?
    halt 400, "Du har inte föremålet" unless Inventory.has?(@run['id'], req)
  end

  Inventory.add(@run['id'], action['gives_item'])      if action['gives_item']   && !action['gives_item'].empty?
  Inventory.remove(@run['id'], action['removes_item'])  if action['removes_item'] && !action['removes_item'].empty?

  RunLog.create(@run['id'], action['id'], action['name'], action['result'])

  if action['moves_to_next'] == 1
    current_room = Room.find(@run['current_room_id'])
    next_room    = Room.next_room(adventure_id, current_room['room_order'])
    if next_room
      PlayerRun.move_to_room(@run['id'], next_room['id'])
    else
      PlayerRun.finish(@run['id'])
    end
  end

  session[:last_result] = action['result']
  redirect "/adventure/#{adventure_id}"
end

# ────────────────────────────────────────
# Admin: hantera användare
# Alla routes skyddas av before '/admin*'-filtret.
# ────────────────────────────────────────

# Visar adminpanelen med en lista över alla registrerade användare.
# Åtkomst kräver adminbehörighet (hanteras av before '/admin*'-filtret).
#
# @return [String] renderad HTML via Slim-mallen :'admin/users'
get '/admin/users' do
  @users = User.all
  slim :'admin/users'
end

# Togglar adminbehörighet för en given användare.
# En admin kan inte ändra sina egna rättigheter.
# Returnerar 404 om den angivna användaren inte hittas.
# Åtkomst kräver adminbehörighet (hanteras av before '/admin*'-filtret).
#
# @param id [String] route-parameter – målanvändarens databas-id
# @return [void]
post '/admin/users/:id/toggle_admin' do
  target_id = params[:id].to_i
  redirect('/admin/users?error=Kan+inte+ändra+egna+rättigheter') if target_id == session[:user_id]
  target = User.find(target_id)
  halt 404, "Användaren hittades inte" unless target
  User.set_admin(target_id, target['is_admin'] == 0)
  redirect '/admin/users'
end

# Raderar en användare permanent.
# Alla kopplade spelomgångar, inventory och loggar tas bort via ON DELETE CASCADE.
# En admin kan inte radera sitt eget konto via denna route.
# Åtkomst kräver adminbehörighet (hanteras av before '/admin*'-filtret).
#
# @param id [String] route-parameter – målanvändarens databas-id
# @return [void]
post '/admin/users/:id/delete' do
  target_id = params[:id].to_i
  redirect('/admin/users?error=Kan+inte+radera+sig+själv') if target_id == session[:user_id]
  User.delete(target_id)
  redirect '/admin/users'
end