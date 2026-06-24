unless Object.method_defined?(:tainted?)
  class Object
    def tainted?
      false
    end

    def untaint
      self
    end
  end
end
