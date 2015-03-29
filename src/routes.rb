Cuba.define do

    on csrf.unsafe? do
        csrf.reset!
        res.status = 403
        res.redirect 'https://jurassicsystems.com/theking'

        halt(res.finish)
    end

    on 'ban' do
        if session[:admin]
            run Ban
        else
            res.redirect '/login'
        end
    end

    on 'login' do
        unless session[:admin]
            run Login
        else
            res.redirect '/ban'
        end
    end

    on 'logout' do
        session.delete :admin
        res.redirect '/login'
    end

    on root do
        res.redirect '/ban'
    end
end
