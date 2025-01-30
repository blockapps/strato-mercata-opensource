import path from 'path';
import bodyParser from 'body-parser';
import cors from 'cors';
import express from 'express';
import expressWinston from 'express-winston';
import helmet from 'helmet';
import winston from 'winston';

import { 
  clientErrorHandler, 
  commonErrorHandler, 
  validatePaymentServiceContract ,
  validateRedemptionServiceContract,
  verifyDatabaseConnection,
} from './helpers/utils.js';
import { 
  STRIPE_CONTRACT_ADDRESS, 
  // METAMASK_CONTRACT_ADDRESS, // TODO: Disabled for initial payment server release
  REDEMPTION_CONTRACT_ADDRESS,
} from './helpers/constants.js';
import routes from './routes.js';

const config = {
  name: 'Payment Server',
  port: process.env.PORT || 8018,
};

const app = express();

// Middleware
app.use(helmet());
app.use(bodyParser.json());
app.use(cors());

// Logging
app.use(
  expressWinston.logger({
    transports: [new winston.transports.Console()],
    meta: true,
    expressFormat: true
  })
);

// Routes
app.use('/', routes);
app.use(express.static(path.join(process.cwd(), 'public')));

// Error Handlers
app.use(clientErrorHandler);
app.use(commonErrorHandler);

app.listen(config.port, async (e) => {
  if(e) {
      throw new Error('Internal Server Error');
  }
  // TODO: Disabled for initial payment server release
  // console.log(
  //   `
  //          ##+++                                                                +++##             
  //         #####*++++                                                        ++++*#####            
  //         #######*+++++++                                              +++++++*#######            
  //        ###########*++++++++++                                  ++++++++++*###########           
  //       ##############*++++++++++++                          ++++++++++++###############          
  //       #################++++++++++++======================+++++++++++*#################          
  //      ####################*++++++++++====================++++++++++*####################         
  //       ######################++++++++====================++++++++######################          
  //       ########################*++++++==================++++++*########################          
  //       ###########################+++++================+++++###########################          
  //        ############################*++================++*############################           
  //        ###############################+==============+###############################           
  //         ################################============################################            
  //         ##############################++============++##############################            
  //       ##############################++++============++++##############################          
  //         #########################*++++++============++++++*#########################            
  //        ########################*++++++++============++++++++*########################           
  //          ####################*++++++++++============++++++++++*####################             
  //         ###############*+====+++++++++++============+++++++++++====+*###############            
  //           #######*+========+++++++++++++============+++++++++++++========+*#######              
  //            *+=============++++++++++++++============++++++++++++++=============+*               
  //            ==============+++++++++++++++============+++++++++++++++==============               
  //           ==============+++++++++++++++++==========+++++++++++++++++==============              
  //           ================+++++++++++++++==========+++++++++++++++================              
  //          ==================+++++++++*++++==========++++*+++++++++==================             
  //         ====================++++*#%%%#+++==========+++#%%%#*++++====================            
  //         ====================++===+*#%%#++==========++#%%#*+===++====================            
  //        =================================+==========+=================================           
  //        ==============================================================================           
  //       ================================================================================          
  //       ++++++++++++++++++++++++++============================++++++++++++++++++++++++++          
  //        +++++++++++++++++++++++++++========================+++++++++++++++++++++++++++           
  //        +++++++++++++++++++++++++++++====================++++++++++++++++++++++++++++=           
  //         ++++++++++++++++++++++++++++++==+%########%+==++++++++++++++++++++++++++++++            
  //         =+++++++++++++++++++++++++++=--=@@@@@@@@@@@@=--=++++++++++++++++++++++++++++            
  //          +++++++++++++++++++++++==--:::+@@@@@@@@@@@@+:::--==+++++++++++++++++++++++             
  //           ++++++++++++++++++++--:::::::#@@@@@@@@@@@@#-::::::--++++++++++++++++++++              
  //           ++++++++++++++++    ------::-#++++++++++++#-::------    ++++++++++++++++              
  //           +++++++++++           ----------------------------           +++++++++++              
  //            +++                     ----------------------                     +++               
  //                                       ----------------                                          
  //                                       
  //                                       
  // `)
  console.log(`Listening on port ${config.port}...`);
  console.log(`Running database connection verification...`);
  try {
    await verifyDatabaseConnection();
  } catch (e) {
    throw new Error('Database connection cannot be verified.');
  }
  console.log(`SKIP_CONTRACT_VALIDATION: ${process.env.SKIP_CONTRACT_VALIDATION}`);
  if (!process.env.SKIP_CONTRACT_VALIDATION) {
    await validatePaymentServiceContract(STRIPE_CONTRACT_ADDRESS);
    // TODO: Disabled for initial payment server release
    // await validatePaymentServiceContract(METAMASK_CONTRACT_ADDRESS);
    await validateRedemptionServiceContract(REDEMPTION_CONTRACT_ADDRESS);
  }
});