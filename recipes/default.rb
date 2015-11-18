
# Test that everything works if a databag is present
if node.is_in_whitelist? "whitelist"
  log "New Hawtness!"
else
  raise "This is old boring stuff we should not be in here for our mocked data"
end

# Testing that something that doesnt exist doesn't fail everything
if node.is_in_whitelist? "dont-exist"
  raise "This wasn't found we should definitly not be in here"
end
