Rails.application.config.dartsass.build_options << "--load-path=node_modules"
# Primer's Sass variables still use global map functions; silence deprecations from node_modules, not ours.
Rails.application.config.dartsass.build_options << "--quiet-deps"
