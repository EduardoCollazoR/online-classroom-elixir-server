defmodule Classroom.DrawerStore do
  '''
  One drawer per student, will be per students in each class
  '''
  use GenServer

  def start_link(_args) do
    # debug: [:trace]
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def notifly_change(username) do
    GenServer.cast(__MODULE__, {:notifly_change, username})
  end

  def get_all_filename(username) do
    GenServer.call(__MODULE__, {:get_all_filename, username})
  end

  def get_file_data(path, filename) do
    GenServer.call(__MODULE__, {:get_file_data, path, filename})
  end

  def share(path, filename, username) do
    GenServer.call(__MODULE__, {:share, path, filename, username})
  end

  def delete(path, filename) do
    GenServer.call(__MODULE__, {:delete, path, filename})
  end

  def init(_args) do
    {:ok, nil}
  end

  def handle_cast({:notifly_change, username}, nil) do
    {:ok, user_pid} = Classroom.ActiveUsers.find_pid_by_user(username)
    send user_pid, {:notifly_change, return_all_file_list(username)}
    {:noreply, nil}
  end

  def handle_call({:get_all_filename, username}, _from, nil) do
    {:reply, return_all_file_list(username), nil}
  end

  def handle_call({:get_file_data, path, filename}, _from, nil) do
    # Should be HTTP GET request from client, so move this func to upload.ex
  end

  def handle_call({:share, path, filename, share_target}, _from, nil) do
    path = "#{Path.expand("~/tmp_upload")}/#{share_target}/"
    File.mkdir_p! path

    # filepath = get_no_repeat_filepath(path, data.filename, 0)
    #...
    {:reply, :ok, nil}
  end

  def handle_call({:delete, path, filename, username}, _from, nil) do
    {:reply, :ok, nil}
  end

  defp return_all_file_list(username) do
    Path.wildcard(Path.expand("~/tmp_upload/#{username}/*.*")) # do not support sub-directory
    |> Enum.map(&Path.basename/1)
  end

end
