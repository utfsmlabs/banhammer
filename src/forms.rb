class BanForm < Reform::Form
    property :username
    property :duration, virtual: true
    property :because

    validates :username, presence: true
    validates :duration, numericality: true
    validates :because, presence: true
end

class LoginForm < Reform::Form
    property :username, virtual: true
    property :password, virtual: true

    validates :username, presence: true
    validates :password, presence: true
end