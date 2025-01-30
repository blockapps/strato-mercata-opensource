import reducer from '../../components/DeployDapp/deployDapp.reducer';
import {
  deployDappOpenModal,
  deployDappCloseModal,
  openAddMemberModal,
  closeAddMemberModal,
  openAddIntegrationModal,
  closeAddIntegrationModal,
  resetError,
  deployDapp,
  deployDappSuccess,
  deployDappFailure,
} from '../../components/DeployDapp/deployDapp.actions';

describe('DeployDapp: reducer', () => {

  // INITIAL_STATE
  test('set initial state', () => {
    expect(reducer(undefined, {})).toMatchSnapshot();
  });

  describe('deploy dapp modal', () => {

    // OPEN_OVERLAY
    test('open overlay', () => {
      let initialState = {
        isAddMemberModalOpen: false,
        isAddIntegrationModalOpen: false,
        isOpen: false,
        spinning: false,
        key: null,
        error: null,
        abi: null
      };

      const action = deployDappOpenModal();
      expect(reducer(initialState, action)).toMatchSnapshot();
    });

    // CLOSE_OVERLAY
    test('close overlay', () => {
      let initialState = {
        isAddMemberModalOpen: false,
        isAddIntegrationModalOpen: false,
        isOpen: false,
        spinning: false,
        key: null,
        error: null
      };

      const action = deployDappCloseModal();
      expect(reducer(initialState, action)).toMatchSnapshot();
    });

  });

  describe('add member modal', () => {

    // OPEN_ADD_MEMBER_MODAL
    test('open overlay', () => {
      const initialState = {
        isAddMemberModalOpen: false,
        isOpen: false,
        spinning: false,
        key: null,
        error: null
      };

      const action = openAddMemberModal();
      expect(reducer(initialState, action)).toMatchSnapshot();
    });

    // CLOSE_ADD_MEMBER_MODAL
    test('close overlay', () => {
      const initialState = {
        isAddMemberModalOpen: true,
        isOpen: true,
        spinning: false,
        key: null,
        error: null
      };

      const action = closeAddMemberModal();
      expect(reducer(initialState, action)).toMatchSnapshot();
    });

  });

  describe('add integration modal', () => {

    // OPEN_ADD_INTEGRATION_MODAL
    test('open overlay', () => {
      const initialState = {
        isAddIntegrationModalOpen: false,
        isOpen: false,
        spinning: false,
        key: null,
        error: null
      };

      const action = openAddIntegrationModal();
      expect(reducer(initialState, action)).toMatchSnapshot();
    });

    // CLOSE_ADD_INTEGRATION_MODAL
    test('close overlay', () => {
      const initialState = {
        isAddIntegrationModalOpen: true,
        isOpen: true,
        spinning: false,
        key: null,
        error: null
      };

      const action = closeAddIntegrationModal();
      expect(reducer(initialState, action)).toMatchSnapshot();
    });

  });

  describe('deploy dapp', () => {

    const payload = {
      label: 'airline cartel 9',
      members: [{ address: "f11b5c42f5b84efa07f6b0a32c3fc545ff509126", enode: "enode://6f8a80d14311c39f35f516fa664deaaaa13e85b2f7…4cac9f77166ad92a0@172.16.0.5:30303?discport=30303" }],
      balances: [{ balance: 500000000000000, address: "f11b5c42f5b84efa07f6b0a32c3fc545ff509126" }],
      integrations: {},
      src: `contract SimpleStorage {
        uint public storedData;
      }`,
      args: { addRule: "MajorityRules", removeRule: "MajorityRules" }
    }

    // CREATE_CHAIN_REQUEST
    test('request', () => {
      const initialState = {
        isAddMemberModalOpen: false,
        isOpen: false,
        spinning: false,
        key: null,
        error: null
      };

      const action = deployDapp(payload.label, payload.members, payload.balances, payload.integrations, payload.src, payload.args);
      expect(reducer(initialState, action)).toMatchSnapshot();
    });

    // CREATE_CHAIN_SUCCESS
    test('success', () => {
      const initialState = {
        isAddMemberModalOpen: false,
        isOpen: true,
        spinning: true,
        key: null,
        error: null
      };

      const action = deployDappSuccess('64885c49cdc6fe5f15975596115a120ec1e9a616e88a22e0be0457f373d75b73');
      expect(reducer(initialState, action)).toMatchSnapshot();
    });

    // CREATE_CHAIN_FAILURE
    test('failure', () => {
      const initialState = {
        isAddMemberModalOpen: false,
        isOpen: true,
        spinning: true,
        key: null,
        error: null
      };

      const action = deployDappFailure('error');
      expect(reducer(initialState, action)).toMatchSnapshot();
    });

  })

  test('reset error', () => {
    const initialState = {
      isAddMemberModalOpen: true,
      isOpen: true,
      spinning: false,
      key: null,
      error: 'error'
    };

    const action = resetError();
    expect(reducer(initialState, action)).toMatchSnapshot();
  });

});