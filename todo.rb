require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'rack'
require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, escape_html: true
end

configure(:development) do
	require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

helpers do
  # def sanitize_html(content)
  #   Rack::Utils.escape_html(content)
  # end
  def check_list_validity(list)
    return if list

    @storage.error_status('Sorry, that todo list does not exist')
    # session[:error] = 'Sorry, that todo list does not exist'
    redirect '/lists'
  end

  def todos_count(list)
    list[:todos].count
  end

  def list_completed?(list)
    !list[:todos].empty? && todos_completed_count(list) == todos_count(list)
  end

  def todos_completed_count(list)
    list[:todos].select { |todo| todo[:completed] }.count
  end

  def list_class(list)
    'complete' if list_completed?(list)
  end

  def sort_completed_lists(lists, &block)
    # # Iterate lists with index, add list and idx as nested subarrays
    # sorted_arr = []
    # lists.each { |list| sorted_arr << [list] }

    # # Sort the subarrays based off of the lists todos being completed
    # # sorted_arr = sorted_arr.sort_by { |subarr| subarr[0][:id] }
    # sorted_arr = sorted_arr.sort_by { |subarr| list_completed?(subarr[0]) ? 1 : 0 }

    # # Iterate the array, yield each list/list_idx for client rendering
    # sorted_arr.each(&block)
    complete_lists, incomplete_lists = lists.partition { |list| list_completed?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_completed_todos(todos, &block)
    # # Iterate todos with index, add todo and idx as nested subarrays
    # sorted_arr = []
    # todos.each { |todo| sorted_arr << [todo] }

    # # Sort the subarrays based off of the todos being completed
    # sorted_arr = sorted_arr.sort_by { |subarr| subarr[0][:completed] == true ? 1 : 0 }

    # # Iterate the array, yield each todo/todo_idx for client rendering
    # sorted_arr.each(&block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

before do
  @storage = DatabasePersistence.new(logger)
  # @storage = SessionPersistence.new(session)
  # session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = @storage.all_lists
  # @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# View single list
get '/lists/:list_id' do 
  params_list_id = params[:list_id].to_i
  @list = @storage.find_list(params_list_id)
  # @list = session[:lists].find { |list| list[:id] == params_list_id }
  check_list_validity(@list)
  @list_name = @list[:name]
  @list_id = @list[:id]
  @todos = @list[:todos]
  erb :list, layout: :layout
end

# Render the edit list form
get '/lists/:list_id/edit_list' do
  @list_id = params[:list_id].to_i
  @list = @storage.find_list(@list_id)
  # @list = session[:lists].find { |list| list[:id] == @list_id }
  check_list_validity(@list)
  erb :edit_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(list_name)
  if !(1..100).cover? list_name.size
    'Please enter a list name between 1 and 100 characters long.'
  elsif @storage.all_lists.any? { |list| list[:name] == list_name }
    "\"#{list_name}\" already exists. Please enter unique list name between 1 and 100 characters long."
  end
end

# def next_list_id(lists)
#   max_num = lists.map { |list| list[:id].to_s.to_i }.max
#   max_num.nil? ? 1 : max_num + 1
# end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip
  @lists = @storage.all_lists
  # @lists = session[:lists]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    # session[:error] = error
    erb :new_list, layout: :layout
  else
    @lists <<@storage.create_new_list(list_name)
    # id = next_list_id(@lists)
    # @lists << { id: id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    # session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Edit list name
post '/lists/:list_id' do
  new_list_name = params[:list_name].strip
  @list_id = params[:list_id].to_i
  @list = @storage.find_list(@list_id)
  # @list = session[:lists].find { |list| list[:id] == @list_id }
  check_list_validity(@list)

  error = error_for_list_name(new_list_name)
  if error
    session[:error] = error
    # session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.edit_list_name(@list_id, new_list_name)
    # @list[:name] = new_list_name
    session[:success] = 'The list has been updated.'
    # session[:success] = 'The list has been updated.'
    redirect "/lists/#{@list[:id]}"
  end
end

# Delete entire list
post '/lists/:list_id/delete_list' do
  @list_id = params[:list_id].to_i
  @storage.delete_list(@list_id)
  # session[:lists].reject! { |list| @list_id == list[:id] }
  session[:success] = 'The list has been deleted successfully.'
  # session[:success] = 'The list has been deleted successfully.'

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    redirect '/lists'
  end
end

# Return an error message if the todo name is invalid. Return nil if name is valid.
def error_for_todo_name(todo_name, list)
  if !(1..100).cover? todo_name.size
    'Please enter a todo name between 1 and 100 characters long.'
    # elsif list[:todos].any? { |todo| todo[:name] == todo_name }
    # "\"#{todo_name}\" already exists. Please enter unique todo name between 1 and 100 characters long."
  end
end

# def next_todo_id(todos)
#   max_num = todos.map { |todo| todo[:id].to_s.to_i }.max
#   max_num.nil? ? 1 : max_num + 1
# end

# Create new todo item and add to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = @storage.find_list(@list_id)
  # @list = session[:lists].find { |list| list[:id] == @list_id }
  check_list_validity(@list)
  todo_name = params[:todo].strip

  error = error_for_todo_name(todo_name, @list)
  if error
    session[:error] = error
    # session[:error] = error
    erb :list, layout: :layout
  else
    # todo_id = next_todo_id(@list[:todos])
    # @storage.create_todo()
    @storage.create_todo(@list_id, todo_name)
    # @list[:todos] << { id: todo_id, name: todo_name, completed: false }

    session[:success] = 'The todo was added.'
    # session[:success] = 'The todo was added.'
    redirect "/lists/#{@list[:id]}"
  end
end

# Delete todo item
post '/lists/:list_id/todos/:todo_id/delete_todo' do
  @list_id = params[:list_id].to_i
  @list = @storage.find_list(@list_id)
  # @list = session[:lists].find { |list| list[:id] == @list_id }
  check_list_validity(@list)

  @todo_id = params[:todo_id].to_i
  @storage.delete_todo_from_list(@list_id, @todo_id)

  # @list[:todos].reject! { |todo| todo[:id] == @todo_id }
  # @list[:todos].delete_at(@todo_id)

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    session[:success] = 'The todo has been deleted successfully.'
    redirect "/lists/#{@list[:id]}"
  end
end

# Mark single todo complete/incomplete
post '/lists/:list_id/todos/:todo_id/change_state' do
  @list_id = params[:list_id].to_i
  @list = @storage.find_list(@list_id)
  check_list_validity(@list)

  @todo_id = params[:todo_id].to_i
  completed_status = params[:completed] == 'true' ? "t" : "f"

  # Find specific todo and mark complete/incomplete
  @storage.mark_todo_complete(@list_id, @todo_id, completed_status) 
  # todo = @list[:todos].find { |todo| todo[:id] == @todo_id }
  # todo[:completed] = completed_status

  session[:success] = 'The todo has been updated'
  # session[:success] = 'The todo has been updated'
  redirect "/lists/#{@list[:id]}"
end

# Mark all todos in a list as complete
post '/lists/:list_id/todos/complete_all' do
  @list_id = params[:list_id].to_i
  @list = @storage.find_list(@list_id)
  # @list = session[:lists].find { |list| list[:id] == @list_id }
  check_list_validity(@list)

  @storage.mark_all_todos_complete(@list_id, 't')
  # @list[:todos].each do |todo|
  #   todo[:completed] = true
  # end

  session[:success] = 'All todos have been marked as completed.'
  # session[:success] = 'All todos have been marked as completed.'
  redirect "/lists/#{@list[:id]}"
end

set :session_secret, SecureRandom.hex(32)
