local claims = { email_verified: false } + std.extVar('claims');
{
  identity: {
    traits: {
      [if 'email' in claims && claims.email_verified then 'email' else null]: claims.email,
      name: {
        first: claims.given_name,
        last: claims.family_name,
      },
    },
    metadata_public: {
      idp_verification: {
        google: {
          email_verified: claims.email_verified,
        },
      },
    },
  },
}
