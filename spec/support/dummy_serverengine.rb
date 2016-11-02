class DummyServerengine
  def initialize
  end

  def startup
    @server = nil
    if defined?(ServerEngine) # for v0.14. in_forward requires socket manager server
      socket_manager_path = ServerEngine::SocketManager::Server.generate_path
      @server = ServerEngine::SocketManager::Server.open(socket_manager_path)
      ENV['SERVERENGINE_SOCKETMANAGER_PATH'] = socket_manager_path.to_s
    end
    @server
  end

  def shutdown
    @server.close if @server
  end
end
