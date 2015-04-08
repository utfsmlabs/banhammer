
class Login < Cuba; end

Login.define do
    on root do
        @login_form = LoginForm.new(nil)
        on get do
            render 'login'
        end

        on post do
            unless @login_form.validate req.params
                res.status = 401
                @error_message = "Ah, ah, ah. You didn't say the magic word."
                render 'login'
                halt(res.finish)
            end

            ldap_cfg = Cuba.settings[:banhammer]['LDAP']
            primos = Cuba.settings[:banhammer]['Primos']

            @login_form.save do |form|

                unless primos.include? form[:username]
                    @error_message = "No eres primo. Deberíamos banearte >:C"
                    res.status = 403
                    render 'login'
                    halt(res.finish)
                end

                ldap_clt = Net::LDAP.new :host => ldap_cfg['server'],
                                    :port => ldap_cfg['port'],
                                    :auth => {
                                        :method => :simple,
                                        :username => ldap_cfg['admin_dn'],
                                        :password => ldap_cfg['admin_password']
                                    }

                filter = Net::LDAP::Filter.eq 'uid', form[:username]

                user_dn = nil
                ldap_clt.search :base => ldap_cfg['basedn'], :filter => filter do |result|
                    user_dn = result.dn
                end

                #ldap_clt.auth user_dn, form[:password]
                begin
                    unless ldap_clt.bind_as :base => user_dn, :password => form[:password]
                        @error_message = "Revisa bien la contraseña. Quizás fuiste baneado."
                        res.status = 401
                        render 'login'
                        halt(res.finish)
                    else
                        session[:admin] = form[:username]
                    end
                rescue BindingInformationInvalidError
                    @error_message = "Al parecer no hay acceso al servidor LDAP :C"
                    res.status = 500
                    render 'login'
                    halt(res.finish)
                end
                res.redirect '/ban'
            end
        end
    end
end