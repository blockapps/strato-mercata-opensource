import { rest, oauthUtil } from "blockapps-rest";
import jwtDecode from "jwt-decode";
import config from "../load.config.js";

const options = { config };

// Yadvendra: Adding error context to the oauth initialization
let oauth = null;

const getOAuth = async () => {
  if (!oauth) {
    try {
      oauth = await oauthUtil.init(config.nodes[0].oauth);
    } catch (error) {
      console.error('Failed to initialize OAuth:', error.message);
      throw new Error(`OAuth initialization failed: ${error.message}`);
    }
  }
  return oauth;
};

const getEmailIdFromToken = function (accessToken) {
  return jwtDecode(accessToken).email;
};

async function createStratoUser(accessToken) {
  try {
    const user = await rest.createUser(accessToken, options);
    return { status: 200, message: "success", user };
  } catch (e) {
    return {
      // eslint-disable-next-line no-nested-ternary
      status: e.response
        ? e.response.status
        : e.code
        ? e.code
        : "NO_CONNECTION",
      message: "error while creating user",
    };
  }
}

const getUserToken = async (username, password) => {
  try {
    const oauthInstance = await getOAuth();
    // Fetch a new token using Resource Owner Password Credentials
    const tokenObj = await oauthInstance.getAccessTokenByResourceOwnerCredential(
      username,
      password
    );
    return {
      token:
        tokenObj.token[
          config.nodes[0].oauth.tokenField
            ? config.nodes[0].oauth.tokenField
            : "access_token"
        ],
    };
  } catch (error) {
    console.error('Failed to get user token:', error.message);
    throw error;
  }
};

const getServiceToken = async () => {
  try {
    const oauthInstance = await getOAuth();
    const tokenObj = await oauthInstance.getAccessTokenByClientSecret();
    const new_token =
      tokenObj.token[
        config.nodes[0].oauth.tokenField
          ? config.nodes[0].oauth.tokenField
          : "access_token"
      ];
    const now = Math.floor(Date.now() / 1000);
    const expiresAt = Math.floor(tokenObj.token.expires_at / 1000);
    return { token: new_token, expiration: expiresAt - now };
  } catch (error) {
    console.error('Failed to get service token:', error.message);
    throw error;
  }
};

export default {
  getEmailIdFromToken,
  createStratoUser,
  getServiceToken,
  getUserToken,
  getOAuth,
};
