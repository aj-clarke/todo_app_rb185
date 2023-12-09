class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(list_id)
    all_lists.find { |list| list[:id] == list_id }
    # @session[:lists].find { |list| list[:id] == params_list_id }
  end

  def find_todo(list, todo_id)
    list[:todos].find { |todo| todo[:id] == todo_id }
  end

  def all_lists
    @session[:lists]
  end

  def error_status(error)
    @session[:error] = error
  end

  def success_status(success)
    @session[:success] = success
  end

  def delete_list(list_id)
    all_lists.reject! { |list| list_id == list[:id] }
    # @session[:lists].reject! { |list| list_id == list[:id] }
  end

  def create_new_list(list_name)
    id = next_list_id(@session[:lists])
    @session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def create_todo(list, todo_name)
    todo_id = next_todo_id(list[:todos])
    # @storage[:lists][:list[list]][:todos] << { id: todo_id, name: todo_name, completed: false }
    list[:todos] << { id: todo_id, name: todo_name, completed: false }
  end

  def mark_all_todos_complete(list)
    list[:todos].each do |todo|
      todo[:completed] = true
    end
  end

  def delete_todo_from_list(list, todo_id)
    list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def edit_list_name(list, new_list_name)
    list[:name] = new_list_name
  end

  private

  def next_list_id(lists)
    max_num = lists.map { |list| list[:id].to_s.to_i }.max
    max_num.nil? ? 1 : max_num + 1
  end

  def next_todo_id(todos)
    max_num = todos.map { |todo| todo[:id].to_s.to_i }.max
    max_num.nil? ? 1 : max_num + 1
  end
end