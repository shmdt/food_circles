PUBLISHABLE_KEY =  'pk_test_tAV2hmhGG7SZlSrft4JGEFKU'
SECRET_KEY = 'sk_test_DvrCPEOC0PSt5NV1US7cYmce'
Rails.configuration.stripe = {

    :publishable_key => PUBLISHABLE_KEY,
    :secret_key      => SECRET_KEY
}

Stripe.api_key = Rails.configuration.stripe[:secret_key]