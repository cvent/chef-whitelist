require 'chef/mixin/language'

class Chef
  class Node
    include Chef::DSL::DataQuery

    # Public: find out if the node's fqdn is in a given whitelist. With
    # default settings you need a databag under "whitelist" with an array of
    # hostname patterns under the "patterns" key.
    #
    # Optionally, include a 'roles' key to specify one or more roles to
    # find the node in. This is useful in cases where nodes don't follow a
    # similar naming convention but share a common role.
    #
    # Examples:
    #  (Default data structure)
    #
    # {
    #   "id": "my_whitelist",
    #   "patterns": [
    #     "host.example.com",
    #     "*.subdomain.example.com",
    #     "prefix*.example.com"
    #   ]
    # }
    #
    #  (With the optional 'roles' key)
    # {
    #   "id": "my_whitelist",
    #   "patterns": [
    #     "host.example.com",
    #     "*.subdomain.example.com",
    #     "prefix*.example.com"
    #   ],
    #   "roles": [
    #     "Webserver",
    #     "DatabaseServer"
    #   ]
    # }
    #
    # node.is_in_whitelist? "my_whitelist"
    #
    # Once we get a data bag, we cache it in the node.run_state object, which
    # expires at the end of the run. This can significantly speed up chef runs
    # when you need access to the same whitelist multiple times.
    #
    # Parameters:
    #   whitelist - the whitelist to check for the host
    #   data_bag  - the higher level data_bag containing the whitelist
    #               (default: "whitelist")
    #   attribute - the data_bag atttribute which contains the host list
    #               (default: "patterns")
    #
    # Returns true if the node is in the whitelist and false otherwise
    def is_in_whitelist?(whitelist, data_bag="whitelist", attribute="patterns")
      whitelist_config = load_whitelist_config(whitelist, data_bag)
      patterns = whitelist_config[attribute] || []

        patterns.each do |pattern|
            if (File.fnmatch?(pattern, self[:fqdn] || ''))
                Chef::Log.info "Whitelisting: Matched pattern '#{pattern}' to host '#{self[:fqdn]}' for whitelist '#{whitelist}'."
                return true
            end
        end

        if whitelist_config.has_key?( "roles" )
            roles = whitelist_config["roles"]
            node_found_in_role = search_node_in_roles( roles )
            if node_found_in_role
                Chef::Log.info "Whitelisting: Found node '#{self[:fqdn]}' via role search for whitelist '#{whitelist}'."
                return true
            else
                Chef::Log.info "Whitelisting: Node '#{self[:fqdn]}' wasn't found via role search for whitelist '#{whitelist}'."
            end
        end

        Chef::Log.info "Whitelisting: Node '#{self[:fqdn]}' didn't match any patterns for whitelist '#{whitelist}'"
        return false
    end

    # Public: Searches for the node based on roles defined in the optional 'roles' key of the whitelist
    # data bag item, if that keys exists. The first match wins regardless of the order of roles specified
    # in the data bag item.
    #
    # Examples:
    #
    #   node_found_in_role = search_node_in_roles( roles )
    #   # => true
    #
    # Parameters:
    #   roles - a String or Array of Strings decribing the roles to search for the node
    #
    # Returns true if the node's fqdn is found in the results of a role search, false otherwise
    def search_node_in_roles( roles )
        roles.each do |r|
            Chef::Log.info "Searching for '#{self[:fqdn]}' in the '#{r}' role."
            if self.role?(r)
                # return true for the first match
                Chef::Log.info "Whitelisting: Found node '#{self[:fqdn]}' via role '#{r}'."
                return true
            end
        end

        return false

    end

    private

    def load_whitelist_config(whitelist, data_bag)
      if node.run_state["whitelistdb_#{whitelist}"].nil?
        begin
          node.run_state["whitelistdb_#{whitelist}"] = data_bag_item(data_bag, whitelist)
        rescue Net::HTTPServerException, Chef::Exceptions::InvalidDataBagPath
          node.run_state["whitelistdb_#{whitelist}"] = { }
          Chef::Log.error "Problem loading `#{whitelist}` in `#{data_bag}` for chef-whitelist library, defaulting to empty whitelist configuration"
        end
      end

      node.run_state["whitelistdb_#{whitelist}"]
    end

  end

end
