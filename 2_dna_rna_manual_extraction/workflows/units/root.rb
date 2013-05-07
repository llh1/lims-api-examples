module Lims::Api::Examples
  module Root

    private 

    def root
     API::new_stage("Get the root JSON")
     API::new_step("Get the root JSON")
     @root_json = API::get_root
    end
  end
end
