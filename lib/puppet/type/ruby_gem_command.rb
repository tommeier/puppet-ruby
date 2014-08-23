Puppet::Type.newtype(:ruby_gem_command) do
  @doc = ""

  ensurable do
    newvalue :present do
      provider.create
    end

    defaultto :present
  end

  def retrieve
    provider.query[:ensure]
  end

  def insync?(is)
    true
  end

  newparam(:gem) do
    validate do |v|
      unless v.is_a? String
        raise Puppet::ParseError,
          "Expected gem to be a String, got a #{v.class.name}"
      end
    end
  end

  newparam(:command) do
    validate do |v|
      unless v.is_a? String
        raise Puppet::ParseError,
          "Expected command to be a String, got a #{v.class.name}"
      end
    end
  end

  newparam(:ruby_version) do
    validate do |v|
      unless v.is_a? String
        raise Puppet::ParseError,
          "Expected ruby_version to be a String, got a #{v.class.name}"
      end
    end
  end

  autorequire :ruby do
    if @parameters.include?(:ruby_version) && ruby_version = @parameters[:ruby_version].to_s
      if ruby_version == "*"
        catalog.resources.find_all { |resource| resource.type == 'Ruby' }
      else
        Array.new.tap do |a|
          a << ruby_version if catalog.resource(:ruby, ruby_version)
        end
      end
    end
  end
end
