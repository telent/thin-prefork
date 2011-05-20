class Thin::Prefork::Project < Thin::Prefork

  # We define #project= and #project methods. Because the parent uses
  # T::P::NamedArgs, this allows :project to be used as an initarg
  def project=(project)
    @project=Projectr::Project[project]
    inotifier=@project.watch_files do |p|
      self.reload
    end
  end
  def project
    @project
  end

  def reload
    self.workers.map(&:stop)
    self.project.load!
    self.workers.map(&:start)
  end

end
