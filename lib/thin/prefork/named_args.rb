class Thin::Prefork
  module NamedArgs
    def set_attr_from_hash(args)
      args.each {|k,v|
        k="#{k}=".to_sym; self.public_methods.include?(k) and self.send(k,v)
      }
    end
  end
end

