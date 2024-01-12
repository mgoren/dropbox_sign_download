require 'dropbox-sign'
require 'signal'
require 'dotenv/load'
require 'pry'
require 'Date'

Signal.trap("INT") do
  puts "Script interrupted."
  exit
end

Dropbox::Sign.configure do |config|
  config.username = ENV['DROPBOX_SIGN_API_KEY']
end

def get_all_signature_requests
  query1 = "complete:true AND created:<2019-01-01"
  query2 = "complete:true AND created:>=2019-01-01"

  signature_request_api = Dropbox::Sign::SignatureRequestApi.new
  page_size=100
  signature_requests=[]
  result = signature_request_api.signature_request_list({page_size: page_size, query: query1})
  total_pages = result.list_info.num_pages
  total_pages.times do |page_number|
    result = signature_request_api.signature_request_list({page_size: page_size, page:page_number+1, query: "complete:true"})
    puts "loading page #{page_number} of #{total_pages}"
    # completed_requests = result.signature_requests.select{|req| !req.test_mode && req.is_complete}
    # signature_requests += completed_requests
    signature_requests += result.signature_requests
  end
  signature_requests
end

def download_requests(requests)
  title_mapping = {
    "Sign to accept the Epicodus Code of Conduct" => "code_of_conduct",
    "Sign to accept the Epicodus Enrollment Agreement" => "enrollment_agreement",
    "Sign to accept the Epicodus Refund Policy" => "refund_policy",
    "Sign to accept the Seattle Complaint Disclosure" => "complaint_disclosure",
    "Sign to accept the Student Internship Agreement" => "student_internship_agreement",
    "Employer Internship Agreement" => "employer_internship_agreement"
  }

  signature_request_api = Dropbox::Sign::SignatureRequestApi.new
    requests.each do |req|
      doc_type = title_mapping[req.title] || 'unknown'
      email = req.signatures.first.signer_email_address
      signed_at = Time.at(req.signatures.first.signed_at).to_datetime.to_s
      filename = "#{email}_#{doc_type}_#{signed_at}.pdf"
      next if File.exist?(filename)
      begin
        puts "downloading: #{req}"
        file_bin = signature_request_api.signature_request_files(req.signature_request_id,{file_type:"pdf"})
        FileUtils.cp(file_bin.path, filename)
      rescue => e
        puts "Error downloading #{filename}, #{e.message}"
      end
      sleep(3)
   end
 end

starting = Time.now
puts "Beginning to load sigature requests at #{starting}"
requests = get_all_signature_requests
ending = Time.now
puts "Finished loading signature requests at #{ending}"
puts "Time elapsed: #{((ending - starting)/60).round(1)} minutes"
puts "Completed signature requests: #{requests.count}"
puts "Beginning download of files"
puts ""
# puts requests
download_requests(requests)
