class Services::Trello < Services::Base
  DEFAULT_LIST_NAME = "Suggestions"
  TRELLO_APPLICATION_KEY_PATH = "https://trello.com/1/api/appKey/generate"
  TRELLO_AUTH_TOKEN_PATH = "https://trello.com/docs/gettingstarted/index.html#getting-a-token-from-a-user"

  name "Trello"

  string :application_key, lambda { _("Application key") }, lambda { _("See %{link}.") % { link: "<a href='#{TRELLO_APPLICATION_KEY_PATH}'>#{TRELLO_APPLICATION_KEY_PATH}</a>".html_safe } }

  string :auth_token, lambda { _("Auth token") }, lambda { _("For accessing private boards. See %{link}.") % { link: "<a href='#{TRELLO_AUTH_TOKEN_PATH}'>#{TRELLO_AUTH_TOKEN_PATH}</a>".html_safe } }

  string :board_id,
    lambda { _("Board ID") },
    lambda { "The ID of your Board." }

  string :list_id_or_name,
    lambda { _("List name or ID") },
    lambda { "Optional. The name or ID of your List. Defaults to a list with name '#{DEFAULT_LIST_NAME}'." }
  
  def perform
    return false if data['auth_token'].blank? || data['board_id'].blank?

    board_id = data['board_id']
    list_id_or_name = data['list_id_or_name']
    list = get_or_create_list board_id, list_id_or_name
  end

  protected

  def api_base_path
    return "https://api.trello.com/1"
  end

  def auth_params
    auth_params = "key=#{data['application_key']}"
    auth_params.concat("&token=#{data['auth_token']}")
    return auth_params
  end

  def board_path board_id
     return api_base_path() + "/#{board_id}"
  end

  def board_lists_path board_id
    return board_path(board_id) + "/lists"
  end

  def create_list board_id, name
    response = request_board_lists :post, board_id, name: name

    if response.is_a? Net::HTTPCreated
      return JSON.parse response.body
    else
      return nil
    end
  end

  def find_list lists, list_id_or_name
    return lists.find { |list| [ list.name, list.id ].include? list_id_or_name }
  end

  def get_board_lists board_id
    response = request_board_lists :get, board_id

    if response.is_a? Net::HTTPSuccess
      return JSON.parse response.body
    else
      return nil
    end
  end

  def get_or_create_list board_id, list_id_or_name
    lists = get_board_lists data['board_id']
    list = nil
    if has_list? lists, data['list_id_or_name']
      list = find_list lists, data['list_id_or_name']
    else
      list_name = data['list_id_or_name'] || DEFAULT_LIST_NAME
      list = create_list board_id, list_id_or_name || DEFAULT_LIST_NAME
    end

    return list
  end

  def has_list? lists, list_id_or_name
    return nil != find_list(lists, list_id_or_name)
  end

  def request_board_lists verb, board_id, params=nil
    request = nil
    uri = URI.parse with_auth(board_lists_path board_id)

    if verb.eql? :get
      request = Net::HTTP::Get.new uri.path
    elsif verb.eql? :post
      request = Net::HTTP::Post.new uri.path
    else
      return # Unsupported verb
    end

    http = Net::HTTP.new uri.host, 443
    http.use_ssl = true

    return http.request request
  end

  def with_auth path
    return path + "?#{auth_params}"
  end
end
