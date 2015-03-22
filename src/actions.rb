Cuba.define do
    on 'ban' do
        on root do
            @bans = Ban.all(:order => [ :ban_date.asc, :ban_until.asc ], :limit => 10)
            render 'index'
        end

        on 'query' do
            on get, param("user") do |user|
                @user_detail = Ban.aggregate(:username, :all.count, :username => user)[0]
                @bans = Ban.all(:fields => [:id, :because, :ban_date, :ban_until, :banned_by],
                                :username => user, :order => [ :ban_date.desc, :ban_until.desc ])
                puts @user_detail
                render 'detail'
            end

            on get do
                res.redirect '/'
            end
        end

        on 'new' do
            @ban_form = BanForm.new(Ban.new)
            on get do
                render 'new_ban'
            end

            on post do
                if @ban_form.validate req.params
                    ldap_cfg = Cuba.settings[:banhammer]["LDAP"]
                    primos = Cuba.settings[:banhammer]["Primos"]

                    @ban_form.save do |form|

                        unless primos.include? form[:banned_by]
                            @error_message = 'No eres primo, te deberíamos banear >:C'
                            render 'new_ban'
                            res.status = 403
                            halt(res.finish)
                        end

                        ldap_clt = Net::LDAP.new :host => ldap_cfg['hostname'], :port => ldap_cfg['port']

                        admin_filter = Net::LDAP::Filter.eq 'uid', form[:banned_by]
                        user_filter = Net::LDAP::Filter.eq 'uid', form[:username]
                        user_dn = ''
                        user_exists = false
                        ldap_clt.search :base => ldap_cfg['basedn'], :filter => admin_filter do |result|
                            user_dn = result.dn
                        end

                        ldap_clt.auth user_dn, form[:admin_password]
                        unless ldap_clt.bind
                            @error_message = 'No pusiste bien tus credenciales, ave.'
                            render 'new_ban'
                            res.status = 403
                            halt(res.finish)
                        end

                        ldap_clt.search :base => ldap_cfg['basedn'], :filter => user_filter do |result|
                            unless Ban.count(:username => form[:username], :unbanned => false) == 0
                                @error_message = 'No se puede banear a alguién que ya se encuentra baneado.'
                                res.status = 409
                                render 'new_ban'
                                halt(res.finish)
                            end
                            @new_password =  TokenPhrase.generate('-')
                            @ban = @ban_form.model
                            @ban.attributes = { :username => form[:username], :banned_by => form[:banned_by],
                                                :because => form[:because], :replacement_password => @new_password,
                                                :ban_until => Date.today.next_day(form[:duration].to_i).to_datetime}

                            @ban.save
                            res.status = 200
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

    on root do
        res.redirect '/ban/'
    end
end
