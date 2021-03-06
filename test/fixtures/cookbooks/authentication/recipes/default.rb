include_recipe 'jenkins::master'

#
# Setup
# ------------------------------

# Generate the SSH key pair
require 'net/ssh'
key = OpenSSL::PKey::RSA.new(4096)
private_key = key.to_pem
public_key  = "#{key.ssh_type} #{[key.to_blob].pack('m0')}"

# Set the private key on the executor
ruby_block 'set the private key' do
  block { node.set['jenkins']['executor']['private_key'] = private_key }
end

# Create a default Chef user with the public key
# For this to succeed PK needs to be automatically unset
jenkins_user 'chef' do
  full_name   'Chef Client'
  public_keys [public_key]
end

# Turn on basic authentication
jenkins_script 'setup authentication' do
  command <<-EOH.gsub(/^ {4}/, '')
    import jenkins.model.*
    def instance = Jenkins.getInstance()

    import hudson.security.*
    def realm = new HudsonPrivateSecurityRealm(false)
    instance.setSecurityRealm(realm)

    def strategy = new hudson.security.FullControlOnceLoggedInAuthorizationStrategy()
    instance.setAuthorizationStrategy(strategy)

    instance.save()
  EOH
end

# Run some commands - this will ensure the CLI is correctly passing attributes
# This will also ensure that the private key has been reset
jenkins_command 'clear-queue'

# Install a plugin
jenkins_plugin 'greenballs'

# Try creating another user
jenkins_user 'schisamo'
