class Thin::Prefork::Project < Thin::Prefork
  module WorkerHelper
    def start!
      Projectr::Project[self.project].load!
    end
    def reload!
      Projectr::Project[self.project].load!
    end
    def app
      @app || self.app_class.new
    end
  end
  def initialize(args)
    app_class=args.delete(:app_class)
    project=args.delete(:project)
    super

    # the purpose of this metagymnastics is to create a new subclass
    # of Thin::Prefork::Worker which has access to the values for
    # +app_class+ and +project+ that were passed as arguments to this
    # constructor.  If you know of a better way, advice/patches welcomed
    parent=self.worker_class || Thin::Prefork::Worker
    w=Class.new(parent)
    w.class_eval do
      include WorkerHelper
    end
    w.send(:define_method,:app_class,Proc.new {|| app_class })
    w.send(:define_method,:project,Proc.new {|| project })
    self.worker_class=w

    # ask the project for the inotifier that will call us when its
    # files change
    p= ::Projectr::Project[project]
    master=self
    inotifier=p.watch_files do |project,name|
      master.reload!
    end

    # register the filehandle for this notifier with the event loop
    # in #run!  The block is called when inotifier.to_io is "ready"
    # for some class of I/O operation
    master.add_io_handler(inotifier.to_io) do |direction|
      inotifier.process
    end
  end
end
