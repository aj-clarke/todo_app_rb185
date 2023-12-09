require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = PG.connect(dbname: 'todos')
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params) # params is already an array
  end

  def find_list(list_id)
    sql_cmd = 'SELECT * FROM lists WHERE id=$1;'
    result = query(sql_cmd, list_id)
    # @logger.info "#{result.entries}"
    tuple = result.first

    todos = find_todos_for_list(list_id)

    { id: tuple["id"].to_i, name: tuple["name"], todos: todos }
  end

  def all_lists
    sql_cmd = 'SELECT * FROM lists;' # SQL cmd to obtain array of hashes with :id and :name columns and data
    result = query(sql_cmd)  # PG::Result object with above data

    result.map do |tuple|  # Iterate PG::Result array object with hash of :id and :name column 
      list_id = tuple["id"].to_i # :id of current row/tuple from `lists` table

      todos = find_todos_for_list(list_id)

      # Create hash containing list info needed to be returned for front-end web display
      {id: list_id, name: tuple["name"], todos: todos}
    end
  end

  def delete_list(list_id)
    query('DELETE FROM todos WHERE list_id=$1;', list_id)
    query('DELETE FROM lists WHERE id=$1;', list_id)
  end

  def create_new_list(list_name)
    sql_cmd = 'INSERT INTO lists (name) VALUES ($1);'
    query(sql_cmd, list_name)
  end

  def create_todo(list_id, todo_name)
    sql_cmd = 'INSERT INTO todos (name, list_id) VALUES ($2, $1);'
    result = query(sql_cmd, list_id, todo_name)
    @logger.info "#{result.entries}"
  end

  def mark_todo_complete(list_id, todo_id, completed_status)
    sql_cmd = 'UPDATE todos SET completed=$3 WHERE id=$2 AND list_id=$1'
    query(sql_cmd, list_id, todo_id, completed_status)
  end

  def mark_all_todos_complete(list_id, sql_true)
    sql_cmd = 'UPDATE todos SET completed=$2 WHERE list_id=$1'
    query(sql_cmd, list_id, sql_true)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql_cmd = 'DELETE FROM todos WHERE id = $1 AND list_id = $2'
    query(sql_cmd, todo_id, list_id)
  end

  def edit_list_name(list_id, new_list_name)
    sql_cmd = 'UPDATE lists SET name=$2 WHERE id=$1;'
    query(sql_cmd, list_id, new_list_name)
  end

  private

  # Build array of hashes of todos for the specified list
  def find_todos_for_list(list_id)
    # SQL cmd to obtain array of hashes with todo :id, :name, and :list_id columns and data
    todo_sql_cmd = 'SELECT * FROM todos WHERE list_id = $1'
    todos_result = query(todo_sql_cmd, list_id) # PG::Result object with above data

    # Iterate PG::Result array object with hash of :id, :name, and :list_id columns
    todos_result.map do |todo_tuple| # todo_tuple is row/tuple of each todo item columns
      # Create hash containing todo info needed to be returned for front-end web display
      { id: todo_tuple['id'].to_i,
        name: todo_tuple['name'],
        completed: todo_tuple['completed'] == 't'
      }
    end
  end
end
