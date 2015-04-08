require 'base64'
require 'digest'
require 'securerandom'
require 'tilt/redcarpet'

class Ban < Cuba; end

Ban.define do
    on root do
        @bans = Ban.all(:unbanned => false, :order => [ :ban_date.asc, :ban_until.asc ], :limit => 10)
        render 'index'
    end

    on 'query' do
        on get, param("user") do |user|
            @user_detail = Ban.aggregate(:username, :all.count, :username => user)
            if @user_detail.count == 0
                @info_message = "El usuario #{user} no tiene baneos registrados"
                render 'query'
            else
                @user_detail = @user_detail[0]
                @bans = Ban.all(:fields => [:because, :ban_date, :ban_until, :banned_by, :unbanned],
                                :username => user, :order => [ :ban_date.desc, :ban_until.desc ])
                render 'detail'
            end
        end

        on get do
            render 'query'
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

                    ldap_clt = Net::LDAP.new :host => ldap_cfg['server'],
                                             :port => ldap_cfg['port'],
                                             :auth => {
                                                :username => ldap_cfg['admin_dn'],
                                                :password => ldap_cfg['admin_password'],
                                                :method => :simple
                                             }

                    user_filter = Net::LDAP::Filter.eq 'uid', form[:username]

                    ldap_clt.search :base => ldap_cfg['basedn'], :filter => user_filter do |result|
                        unless Ban.count(:username => form[:username], :unbanned => false) == 0
                            @error_message = 'No se puede banear a alguién que ya se encuentra baneado.'
                            res.status = 409
                            render 'new_ban'
                            halt(res.finish)
                        end

                        salt = SecureRandom.random_bytes(8)

                        new_password =  TokenPhrase.generate('-')
                        ldap_password = '{ssha}' + Base64.strict_encode64(Digest::SHA1.digest(new_password+salt)+salt)

                        @ban = @ban_form.model
                        @ban.attributes = { :username => form[:username], :banned_by => session[:admin],
                                            :because => form[:because], :replacement_password => new_password,
                                            :current_password => result.userpassword[0],
                                            :ban_until => Date.today.next_day(form[:duration].to_i).to_datetime}

                        if ldap_clt.replace_attribute result.dn, :userpassword, ldap_password
                            @ban.save
                            res.status = 200

                            @image = Dir['./static/images/hammers/*'].sample
                            @image[0] = ''
                            render 'banned'
                            halt(res.finish)
                        else
                            @error_message = 'No se pudo cambiar la contraseña del baneado :C'
                            render 'new_ban'
                            halt(res.finish)
                        end
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

    on 'lift/:user' do |user|
        on get do
            @banned_user = Ban.first(:username => user, :unbanned => false)
            if @banned_user == nil
                @error_message = 'Este usuario no está baneado, extraño...'
                render 'index'
            else
                render 'lift_ban'
            end
        end

        on post do
            @banned_user = Ban.first(:username => user, :unbanned => false)
            if @banned_user == nil
                res.redirect '/ban'
            else
                ldap_cfg = Cuba.settings[:banhammer]["LDAP"]
                ldap_clt = Net::LDAP.new :host => ldap_cfg['server'],
                         :port => ldap_cfg['port'],
                         :auth => {
                            :username => ldap_cfg['admin_dn'],
                            :password => ldap_cfg['admin_password'],
                            :method => :simple
                         }

                user_filter = Net::LDAP::Filter.eq 'uid', @banned_user.username

                ldap_clt.search :base => ldap_cfg['basedn'], :filter => user_filter do |result|
                    unless ldap_clt.replace_attribute result.dn, :userpassword, @banned_user.current_password
                        @error_message = 'No pudimos cambiar la clave del usuario...'
                        res.status = 500
                        render 'lift_ban'
                        halt(res.finish)
                    end
                end

                @banned_user.unbanned = true
                @banned_user.save

                render 'ban_lifted'
            end
        end
    end
end
