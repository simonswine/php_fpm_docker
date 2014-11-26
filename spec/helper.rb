module Helper
  def inst_set(var, value)
    if value.nil?
      value=nil
    else
      if value.is_a? Hash or value.is_a? Array
        value=Marshal.load( Marshal.dump(value))
      else
        value
      end
    end
    a_i.instance_variable_set(var, value)
  end

  def inst_get(var)
    a_i.instance_variable_get(var)
  end

  def method(*args)
    func = self.class.description[1..-1].to_sym
    a_i.instance_exec(func) {|f| send(f,*args)}
  end
end
