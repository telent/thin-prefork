class Thin::Prefork::Project < Thin::Prefork
  attr_accessor :project

  def reload!
    self.project.load!
    super
  end
end
