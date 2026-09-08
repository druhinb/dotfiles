--- Facts about the host that several plugin specs branch on.
return {
  is_ssh = vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil,
}
-- vim: ts=2 sts=2 sw=2 et
