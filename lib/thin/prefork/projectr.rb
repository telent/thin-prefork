class Thin::Prefork::Projectr
  module WorkerMixin
    def reload!
      Project[@project_name].load!
      super
    end
    def start!
      # This will be called *after* your client-specific code.
      # Chances are, then, that you client's start! method (which may
      # want to open databases and stuff) wants to call #super as the
      # first thing it does
      Project[@project_name].load!
    end
  end

  def initialize(args={})
    w=args[:worker_class] || Thin::Prefork::Worker
    w.extend(WorkerMixin)
    @project_name=Project[args.delete[:project]]
    super
  end
end
