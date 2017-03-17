class ItemController < ApplicationController


  def index
    if params["shortname"].present?
      params["f"] = [] if params["f"].blank?
      params["f"] << "shortname|#{params["shortname"]}"
    end
    res = SearchService.new(ES_URI, params, request.fullpath)
      .search_items
    code = res.dig("res", "code")
    render status: code, json: JSON.pretty_generate(res)
  end

  def show
    res = SearchService.new(ES_URI, params, request.fullpath)
      .search_item(params["id"])
    code = res.dig("res", "code")
    render status: code, json: JSON.pretty_generate(res)
  end

end
