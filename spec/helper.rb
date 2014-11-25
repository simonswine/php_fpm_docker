module Helper
  def inst_set(var, value)
    if value.nil?
      value=nil
    else
      value=Marshal.load( Marshal.dump(value))
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
