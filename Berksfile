cookbook 'python', git: "git://github.com/opscode-cookbooks/python.git"
cookbook 'nginx'
cookbook 'supervisor'
cookbook 'postgresql'

group :integration do
  cookbook 'mediacore', path: "."
  cookbook 'mysql'
end
