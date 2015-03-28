
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
                puts 'Holi'
                ldap_clt = Net::LDAP.new :host => ldap_cfg['server'], :port => ldap_cfg['port']
                filter = Net::LDAP::Filter.eq 'uid', form[:username]

                unless primos.include? form[:username]
                    @error_message = "No eres primo. Deberíamos banearte >:C"
                    res.status = 403
                    render 'login'
                    halt(res.finish)
                end

                user_dn = nil
                ldap_clt.search :base => ldap_cfg['basedn'], :filter => filter do |result|
                    user_dn = result.dn
                end

                ldap_clt.auth user_dn, form[:password]
                unless ldap_clt.bind
                    puts 'Holi'
                    @error_message = "Revisa bien la contraseña. Quizás fuiste baneado."
                    res.status = 401
                    render 'login'
                    puts 'Holi'
                    halt(res.finish)
                else
                    session[:admin] = form[:username]
                end
                res.redirect '/ban'
            end
        end
    end
end