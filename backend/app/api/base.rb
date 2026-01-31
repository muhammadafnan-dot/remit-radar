class Base < Grape::API
    format :json

    mount V1::Base
    add_swagger_documentation(
        base_path: '/api',
        api_version: 'v1',
        hide_documentation_path: true,
        hide_format: true,
        info: {
            title: 'Remit Rates API',
            description: 'API for managing remit rates'
        }
    )
end