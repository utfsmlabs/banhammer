
class Ban < Cuba; end

Ban.define do
    on root do
        @bans = Ban.all(:order => [ :ban_date.asc, :ban_until.asc ], :limit => 10)
        render 'index'
    end

    on 'query' do
        on get, param("user") do |user|
            @user_detail = Ban.aggregate(:username, :all.count, :username => user)
            if @user_detail.count == 0
                res.redirect '/'
                halt(res.finish)
            end
        @user_detail = @user_detail[0]
            @bans = Ban.all(:fields => [:id, :because, :ban_date, :ban_until, :banned_by],
                            :username => user, :order => [ :ban_date.desc, :ban_until.desc ])
            puts @user_detail
            render 'detail'
        end

        on get do
            res.redirect '/'
        end
    end

    on 'all' do
        on get do
            bans_per_page = Cuba.settings[:banhammer]["Pagination"]["bans_per_page"]
            @bans = Ban.page(req.params[:page] || 1, :per_page => bans_per_page)
            render 'ban_list'
        end
    end

    on 'new' do
        @ban_form = BanForm.new(Ban.new)
        on get do
            render 'new_ban'
        end

        on post do
            ldap_cfg = Cuba.settings[:banhammer]["LDAP"]
            if @ban_form.validate req.params
                @ban_form.save do |form|

                    ldap_clt = Net::LDAP.new :host => ldap_cfg['server'], :port => ldap_cfg['port']
                    user_filter = Net::LDAP::Filter.eq 'uid', form[:username]

                    ldap_clt.search :base => ldap_cfg['basedn'], :filter => user_filter do |result|
                        unless Ban.count(:username => form[:username], :unbanned => false) == 0
                            @error_message = 'No se puede banear a alguién que ya se encuentra baneado.'
                            res.status = 409
                            render 'new_ban'
                            halt(res.finish)
                        end
                        @new_password =  TokenPhrase.generate('-')
                        @ban = @ban_form.model
                        @ban.attributes = { :username => form[:username], :banned_by => session[:admin],
                                            :because => form[:because], :replacement_password => @new_password,
                                            :ban_until => Date.today.next_day(form[:duration].to_i).to_datetime}

                        @ban.save
                        res.status = 200
                        @image = Dir['./static/images/hammers/*'].sample
                        @image[0] = ''
                        render 'banned'
                        halt(res.finish)
                    end

                    @error_message = 'No pudimos encontrar a la víctima en LDAP :C'
                    render 'new_ban'
                end
            else
                @error_message = 'Faltan datos por rellenar, todos los campos son obligatorios'
                render 'new_ban'
            end
        end
    end
end
