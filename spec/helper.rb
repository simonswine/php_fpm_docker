module Helper
  def dbl_logger
    return @dbl_logger unless @dbl_logger.nil?
    logger=double
    [:debug,:error,:warn,:info,:fatal].each do |loglevel|
      allow(logger).to receive(loglevel)
    end
    @dbl_logger ||= logger
  end

  def mock_logger(c)
    allow(c).to receive(:logger).and_return(dbl_logger)
  end

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
