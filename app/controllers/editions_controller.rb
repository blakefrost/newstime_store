require 'fileutils'

class EditionsController < ApplicationController

  skip_before_filter :verify_authenticity_token, only: :create

  before_filter :force_trailing_slash, only: 'show'

  #before_action :authenticate_user!, only: :purchase

  def show
    @publication = Publication.find_by(slug: params[:publication_slug])
    @edition = @publication.editions.find_by(slug: params[:edition_slug])
    not_found unless @edition
  end

  def new
    @edition = Edition.new
  end

  def browse
    @publication = Publication.find_by(slug: params[:publication_slug])
    @edition = @publication.editions.find_by(slug: params[:edition_slug])

    if params[:format] == 'html'
      # Check referer, is it from the content?
      unless @edition.free? || current_user.try(:owner?, @edition)
        if request.referer != request.original_url && request.referer =~ /\/#{params[:publication_slug]}\/#{params[:edition_slug]}.*\.html/
          pass_count = flash[:pass_count].to_i
          if pass_count.zero?
            flash[:pass_count] = 2 # Every x pages
            @continue_to = request.original_url
            render 'inbetween', status: 403, layout: false and return
          else
            # Grant pass
            flash[:pass_count] = pass_count - 1
          end
        end
      end
    end

    send_file "#{@edition.share_path}/extracted/#{params[:path]}.#{params[:format]}", disposition: 'inline'
  end

  def create
    zip = params.require(:zip)

    # Look up the publication, identified by the slug in the url.
    @publication = Publication.find_by(slug: params[:publication_slug])

    if @publication.editions.where(slug: params[:edition_slug]).exists?
      # Edition exists, receive updates
      @edition = Edition.find_by(slug: params[:edition_slug])

    else
      # Edition doesn't exist for slug, create new edition
      @edition = Edition.new(edition_params)
      @edition.publication = @publication
      @edition.zip_name = zip.original_filename # Copy zip name to the edition.
      @edition.slug = params[:edition_slug]

      @edition.save
    end

    @edition.ensure_share_path!

    File.open(@edition.zip_share_path, 'wb') do |file|
      file.write(zip.read)
    end

    Rails.logger.info `rm -rf #{@edition.share_path}/extracted`
    Rails.logger.info `cd #{@edition.share_path}; unzip #{@edition.zip_name} -d extracted`

    render text: :ok
  end

  def purchase
    @edition = Edition.find(params[:id])
    if current_user
      PurchaseEditionAction.new(current_user, @edition).preform
      redirect_to :back
    else
      redirect_to checkout_edition_path(@edition)
    end
  end

  def checkout
    @edition = Edition.find(params[:id])
    redirect_to @edition.url if current_user
  end

  def search
  end

private

  def edition_params
    params.require(:edition).permit(:name, :publish_date, :price, :volume_label)
  end

end
