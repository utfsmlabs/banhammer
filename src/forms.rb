class BanForm < Reform::Form
    property :username
    property :duration, virtual: true
    property :because
    property :admin_username, from: :banned_by
    property :admin_password, virtual: true

    validates :username, presence: true
    validates :duration, numericality: true
    validates :because, presence: true
    validates :admin_username, presence: true
    validates :admin_password, presence: true
end