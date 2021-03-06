require 'json'
require 'net/https'
require 'net/http'
require 'uri'
require 'openssl'
require 'date'

class FacebookImporter
  def initialize(person_id, token)
    @person_id = person_id
    @token = token
  end
    
  def get_relatives
    uri = URI.parse("https://graph.facebook.com/#{@person_id}/family?access_token=#{@token}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Get.new(uri.request_uri)
    
    response = http.request(request)
    get_info(@person_id)
    @base_person_url = @person_link
    
    relatives = JSON(response.body)
    
    relatives["data"].each do |fbperson|
      @person_id = fbperson["id"]
      @name = fbperson["name"]
      @relation = fbperson["relationship"]
      get_info(@person_id, @relation)
    end if relatives && relatives["data"]
  end
  
  def get_info(person_id, relation_status=nil)
    uri = URI.parse("https://graph.facebook.com/#{person_id}?access_token=#{@token}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Get.new(uri.request_uri)
    
    response = http.request(request)
    fb_obj = JSON(response.body)
    
    @person_id = fb_obj["id"]
    @firstname = fb_obj["first_name"]
    @lastname = fb_obj["last_name"]
    @sex = fb_obj["gender"] if fb_obj["gender"]
    @person_link = fb_obj["link"]
    get_thumbnail(@person_id)
    
    if fb_obj["birthday"] 
      if (/\d{2}\/\d{2}\/\d{4}/ =~ fb_obj["birthday"].to_s) == 0
        @birthdate = Date.strptime(fb_obj["birthday"].to_s, '%m/%d/%Y')
      else
        @birthdate = nil
      end
    else
        @birthdate = nil      
    end
              
    if fb_obj["hometown"]
      @hometown_id = fb_obj["hometown"]["id"]
      @hometown_name = fb_obj["hometown"]["name"]
      get_latlong(@hometown_id)
    end
        
    person = Person.find_or_initialize_by_url(@person_link)
    person.update_attributes(:url => @person_link, :firstname => @firstname, :lastname => @lastname, :sex => @sex, :birthdate => @birthdate, :thumbnail => @profile_pic_url, )
    place = Location.find_or_initialize_by_url(@hometown_link)
    place.url = @hometown_link
    place.name = @hometown_name
    place.lat = @hometown_lat
    place.lon = @hometown_long
    place.save
    if relation_status
      Relation.new_relation_for_people(person,relation_status,Person.find_by_url(@base_person_url))
    end
    person.residences.create(:location_id => place.id, :status => "birthplace")
    p person.inspect
  end
  
  def get_thumbnail(person_id)
    @profile_pic_url = "https://graph.facebook.com/#{person_id}/picture"
  end
  
  def get_latlong(hometown_id)
    uri = URI.parse("https://graph.facebook.com/#{hometown_id}?access_token=#{@token}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Get.new(uri.request_uri)
    
    response = http.request(request)
    location_info = JSON(response.body)
    #raise location_info.inspect 
    @hometown_lat = location_info["location"]["latitude"]
    @hometown_long = location_info["location"]["longitude"]
    @hometown_link = location_info["link"]
  end
  
end
