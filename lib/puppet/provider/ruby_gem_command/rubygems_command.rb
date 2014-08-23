require 'puppet/util/execution'

# TODO : Refactor and share logic with other providers (particuarly rubygems.rb)
# TODO : Update README
# TODO : Write specs
# TODO : Blowup if gem isn't installed or perhaps install?
# Example:
# ruby_gem_command { "pod install":
#     gem          => 'cocoapods',
#     ruby_version => $::ferocia::config::ruby_version,
# }

Puppet::Type.type(:ruby_gem_command).provide(:rubygems_command) do
  include Puppet::Util::Execution
  desc ""

  def self.ruby_versions
    Dir["/opt/rubies/*"].map do |ruby|
      File.basename(ruby)
    end
  end

  def ruby_versions
    self.class.ruby_versions
  end

  # Duplicate of rubygem
  def self.gemlist
    return @gemlist if defined?(@gemlist)

    mapping = Hash.new { |h,k| h[k] = {} }

    Dir["/opt/rubies/*"].each do |ruby|
      v = File.basename(ruby)
      mapping[v] = Array.new

      Dir["#{ruby}/lib/ruby/gems/*/gems/*"].each do |g|
        mapping[v] << File.basename(g)
      end
    end

    @gemlist = mapping
  end

  # Duplicate of rubygems
  def gemlist
    self.class.gemlist
  end

  def query
    {
      :name         => "#{@resource[:command]} for ruby #{@resource[:ruby_version]}",
      :ensure       => :present,
      :gem          => @resource[:gem],
      :ruby_version => @resource[:ruby_version],
      :command      => @resource[:command],
    }
  end

  def create
    if @resource[:online_required] && Facter.value(:offline) == "true"
      raise Puppet::Error, "Unable to run gem command. This command requires being online."
    else
      if @resource[:ruby_version] == "*"
        target_versions = ruby_versions
      else
        target_versions = [@resource[:ruby_version]]
      end
      target_versions.reject { |r| installed_for? r }.each do |ruby|
        gem_command @resource[:command], ruby
      end
    end
  rescue => e
    raise Puppet::Error, "#{e.message}: #{e.backtrace.join("\n")}"
  end

private
  # Override default `execute` to run super method in a clean
  # environment without Bundler, if Bundler is present
  def execute(*args)
    if Puppet.features.bundled_environment?
      Bundler.with_clean_env do
        super
      end
    else
      super
    end
  end

  # Override default `execute` to run super method in a clean
  # environment without Bundler, if Bundler is present
  def self.execute(*args)
    if Puppet.features.bundled_environment?
      Bundler.with_clean_env do
        super
      end
    else
      super
    end
  end

  def gem_command(command, ruby_version)
    bindir = "/opt/rubies/#{ruby_version}/bin"
    execute "#{bindir}/#{command}", {
      :combine            => true,
      :failonfail         => true,
      :uid                => user,
      :custom_environment => {
        "PATH" => env_path(bindir),
        "GEM_PATH" => nil
      }
    }
  end

  def user
    Facter.value(:boxen_user) || Facter.value(:id)
  end

  def installed_for?(ruby_version)
    installed_gems[ruby_version].any? { |g|
      g[:gem] == @resource[:gem] \
        && g[:ruby_version] == ruby_version
    }
  end

  def installed_gems
    @installed_gems ||= Hash.new do |installed_gems, ruby_version|
      installed_gems[ruby_version] = gemlist[ruby_version].map { |g|
        gem_name, _, gem_version = g.rpartition("-")
        {
          :gem          => gem_name,
          :version      => gem_version,
          :ruby_version => ruby_version,
        }
      }
    end
  end

  def env_path(bindir)
    [bindir,
     "#{Facter.value(:boxen_home)}/bin",
     "/usr/bin", "/bin", "/usr/sbin", "/sbin"].join(':')
  end
end