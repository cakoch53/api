=begin
CDRH API

API to access all public Center for Digital Research in the Humanities resources

OpenAPI spec version: 0.1.0

Generated by: https://github.com/swagger-api/swagger-codegen.git

=end

class ItemController < ApplicationController

  def index
    # Expected parameters
    # q
    # f[]
    # facet[]
    # hl
    # min  # TODO implement
    # num
    # sort
    # sort_desc
    # start

    start = params["start"].blank? ? START : params["start"]
    num = params["num"].blank? ? NUM : params["num"]
    req = {
      "aggs" => {},
      "from" => start,
      # always include highlights by default
      "highlight" => {
        "fields" => {
          "cdrh-text" => {
            "fragment_size" => 100, "number_of_fragments" => 3
          }
        }
      },
      "size" => num,
      # sort by _score by default
      "sort" => ["_score"],
      "query" => {},
    }
    bool = {}

    # TEXT SEARCH Q
    if !params["q"].blank?
      # default to searching text field
      # but can search _all field if necessary
      if params["q"].include?("*")
        bool["must"] = { "wildcard" => { "cdrh-text" => params["q"] } }
      else
        bool["must"] = { "match" => { "cdrh-text" => params["q"] } }
      end
    else
      bool["must"] = { "match_all" => {} }
    end

    # FACETS[]
    if !params["facet"].blank?
      aggs = {}
      params["facet"].each do |f|
        # TODO the mapping is incorrect for keywords
        # they should be keywords ONLY and not a multitype
        # the multitype requires the .keyword seen below
        aggs[f] = { "terms" => { "field" => "#{f}.keyword" } }
      end
      req["aggs"] = aggs
    end

    # FILTER FIELDS F[]
    if !params["f"].blank?
      fields = params["f"]
      pairs = fields.map { |f| f.split("|") }
      filter = []
      pairs.each do |pair|
        filter << { "term" => { pair[0] => pair[1] } }
      end
      bool["filter"] = filter
    end

    # HIGHLIGHT
    if !params["hl"].blank? && params["hl"] == "false"
      # remove highlighting from request if they don't want it
      req.delete("highlight")
    end

    # SORT
    sort_asc = params["sort"].blank? ? nil : params["sort"]
    sort_desc = params["sort_desc"].blank? ? nil : params["sort_desc"]
    if sort_asc || sort_desc
      # default to using asc if sent both sort and sort_desc params
      # TODO is this the way we want to handle sorting?
      dir = sort_asc ? "asc" : "desc"
      sort_field = sort_asc ? sort_asc : sort_desc
      sort = { "#{sort_field}.keyword" => { "order" => dir } }
      req["sort"].unshift(sort)
    end

    req["query"]["bool"] = bool

    begin
      puts req
      res = RestClient.post("#{ES_URI}/_search", req.to_json, { "content-type" => "json" })
      body = JSON.parse(res.body)
      # TODO will need to correctly format this for api expected results
      render json: JSON.pretty_generate(body)
    rescue => e
      puts "ERROR: #{e}"
      # TODO correctly format this for api expected results
      render json: { "error" => e }
    end
  end

  def show
    # TODO are we assuming that ids are always unique?
    # if not, we can use the shortname param passed in, also
    req = {
      "query" => {
        "ids" => {
          # "type" => params["shortname"]
          "values" => [params["id"]]
        }
      }
    }
    begin
      res = RestClient.post("#{ES_URI}/_search", req.to_json, { "content-type" => "json" })
      body = JSON.parse(res.body)
      count = body["hits"]["total"]
      # TODO this is NOT the way that we are expecting the response
      # but I'm just woodshedding it in for the moment!
      item = body["hits"]["hits"][0]["_source"]
      render json: JSON.pretty_generate({ "count" => count, "item" => item })
    rescue => e
      # TODO handle this in the open api method
      puts "ERROR: #{e}"
      render json: { "error" => e }
    end
  end
end
