class MetacolsController < ApplicationController

  before_filter :signed_in_user

  def index

    @user_id = params[:user_id] ? params[:user_id].to_i : current_user.id

    if @user_id >= 0

      @user = User.find(@user_id)
      @active_metacols = Metacol.where("status = 'RUNNING' AND user_id = ?", @user_id).order('id DESC')
      @completed_metacols = Metacol.paginate(page: params[:page], :per_page => 10).where("status != 'RUNNING' AND user_id = ?", @user_id).order('id DESC')

    else

      @active_metacols = Metacol.where("status = 'RUNNING'").order('id DESC')
      @completed_metacols = Metacol.paginate(page: params[:page], :per_page => 10).where("status != 'RUNNING'").order('id DESC')

    end

    @daemon_status = ""
    if current_user && current_user.is_admin 
      IO.popen("ps a | grep [r]unner") { |f| f.each_line { |l| @daemon_status += l } } 
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @metacols }
    end
  end

  def show

    @mc = Metacol.find(params[:id])

    @blob = Blob.get @mc.sha, @mc.path
    @sha = @mc.sha
    @path = @mc.path
    @content = @blob.xml
    @errors = ""

    begin
      @metacol = Oyster::Parser.new(@content).parse(JSON.parse(@mc.state, :symbolize_names => true )[:stack].first)
    rescue Exception => e
      @errors = "ERROR: " + e
    end

    if @errors==""
      @metacol.id = @mc.id
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @metacol }
    end

  end

  def parse_args sha, path

    @blob = Blob.get sha, path
    @sha = sha
    @path = path
    @content = @blob.xml
    @parse_errors = ""
    @errors = ""

    begin
      @arguments = Oyster::Parser.new(@content).parse_arguments_only
    rescue Exception => e
      @errors = e
    end

  end

  def arguments

    parse_args params[:sha], params[:path]

    respond_to do |format|
      format.html # arguments.html.erb
      format.json { render json: @metacol }
    end

  end

  def launch

    @info = JSON.parse(params[:info],:symbolize_names => true)
    @blob = Blob.get params[:sha], params[:path]
    @content = @blob.xml
    @arguments = Oyster::Parser.new(@content).parse_arguments_only

    group = Group.find_by_name(@info[:group])
    
    group.memberships.each do |m|

      user = m.user
      args = {}
      @arguments.each do |a|
        ident = a[:name].to_sym
        val = @info[:args][ident]
        if a[:type] == 'number' && val.to_i == val_to_f
          args[indent] = val.to_i
        elsif a[:type] == 'number' && val.to_i != val_to_f
          args[indent] = val.to_f
        elsif a[:type] == 'generic'
          begin
            args[ident] = JSON.parse(val,:symbolize_keys=>true)
          rescue Exception => e
            flash[:error] = "Could not parse json for argument #{a[:name]}: " + e.to_s
            return redirect_to arguments_new_metacol_path(sha: params[:sha], path: params[:path]) 
          end
        else
          val = @info[:args][ident]
        end

      end
      args[:aquarium_user] = user.login

      begin
        @metacol = Oyster::Parser.new(@content).parse args
      rescue Exception => e
        flash[:error] = "Could not start metacol due to parse error. #{@parse_errors}"
        return redirect_to arguments_new_metacol_path(sha: @sha, path: @path) 
      end

      # Save in db
      mc = Metacol.new
      mc.path = params[:path]
      mc.sha = params[:sha]
      mc.user_id = user.id
      mc.status = 'STARTING'
      mc.state = @metacol.state.to_json

      mc.save # save to get an id

      @metacol.id = mc.id

      error = nil
      begin
        @metacol.start
      rescue Exception => e
        error = e
      end

      if !error
        mc.state = @metacol.state.to_json
        mc.status = 'RUNNING'
      else
        mc.message = "On start: " + e.message.split('[')[0]
        mc.status = 'ERROR'
      end

      mc.save # save again for state info

    end

    flash[:notice] = "Starting metacol for each member in group '#{group.name}'. Go to 'Protocols/Pending Jobs' to see jobs started by this metacol."
    redirect_to metacols_path( active: true )

  end

  def log job, type, data
    log = Log.new
    log.job_id = job.id
    log.user_id = current_user.id
    log.entry_type = type
    log.data = data.to_json
    log.save
  end

  def stop

    @metacol = Metacol.find(params[:metacol_id])
    @metacol.status = "DONE"
    @metacol.save

    (@metacol.jobs.select { |j| j.pc == Job.NOT_STARTED }).each do |j|
     j.pc = Job.COMPLETED
     j.save
     log j, "CANCEL", {}
    end

    respond_to do |format|
      format.html { redirect_to metacols_path( active: true ) }
      format.json { head :no_content }
    end
  end

  def destroy

    Metacol.find(params[:id]).destroy
    redirect_to metacols_url(active: 'true')

  end

  def draw

    render 'draw'

  end

  def viewer
  end

end
