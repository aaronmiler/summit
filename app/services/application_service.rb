# Base class for service objects. Invoke with `MyService.call(...)`, which
# builds the instance and runs `#call`. `.new` is private so callers always
# use the one-shot class method — no naked initializes.
#
#   class GreetUser < ApplicationService
#     def initialize(user)
#       @user = user
#     end
#
#     def call
#       "Hi #{@user.name}"
#     end
#   end
#
#   GreetUser.call(user)
class ApplicationService
  def self.call(...)
    new(...).call
  end

  private_class_method :new
end
