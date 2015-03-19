class AccountWidgetsController < WidgetsController
  before_filter :set_account
  before_filter :render_gif_image
  before_filter :render_for_js_format

  def index
    @widgets = AccountWidget.create_widgets(params[:account_id])
  end

  private

  def set_account
    @account = Account.from_param(params[:account_id]).first
  end
end
