**free
  // Offline Mobile example
  // using a Profound UI Universal Display program
  // for the sync web service

  // the same javascript program, puimobile_default is used for this example as
  // is provided for the Profound.js Offline Mobile Example with the only
  // change being the sync web service url

  // puimobile_default.js example provides JSON input in this format:
  // {
  //   "orders":[
  //      {
  //       "ordtlid":1,
  //       "orprice":299.99,
  //       "orprid":102,
  //       "orqty":2
  //      },
  //      {
  //       "ordtlid":2,
  //       "orprice":249.99,
  //       "orprid":103,
  //       "orqty":1
  //      }
  //   ]
  // }

  // the example excpects products returned in the following format
  //  {
  //     "products":[
  //        {
  //           "prid":101,
  //           "prname":"Garmin Nuvi 3790LMT",
  //           "prdesc":"Garmin Nuvi 3790LMT GPS",
  //           "prprice":324.99,
  //           "primage":"/profoundu",
  //           "prqty":76,
  //           "prcatid":101
  //        },
  //        {
  //           "prid":102,
  //           "prname":"Garmin Nuvi 3760LMT",
  //           "prdesc":"Garmin Nuvi 3760LMT GPS Navigation System",
  //           "prprice":399.99,
  //           "primage":"/profoundu",
  //           "prqty":-70,
  //           "prcatid":101
  //        }
  //     ]
  //  }


 // Control Options
 ctl-opt ActGrp(*Caller) Main(Main);

 // display file definition
 Dcl-f OFFLINEMBD workstn
             alias
             extfile(*extdesc)
             extdesc('OFFLINEMBD')
             usropn
             handler('UNIVERSAL(HANDLER)');

 // datastructure template for orders
 Dcl-DS orders_DS qualified template;
   Dcl-DS orders  likeds(order_ds) dim(50);
 End-DS;
 Dcl-DS order_DS template;
   ordtlid packed(5);
   orprice packed(7:2);
   orprid packed(5);
   orqty packed(5);
 End-DS;



 ///////////////////////////////////////////////////////////
 // Main Procedure
 //

 Dcl-Proc Main;

   clear SqlCode;

   If Not %OPEN(OFFLINEMBD);
     Open OFFLINEMBD;
   Endif;

   Update_Orders();

   Return_Products();

   Close OFFLINEMBD;

 End-Proc;

 ////////////////////////////////////////////////////////////////
 // get orders from the request body and update the orders tables
 //
 Dcl-Proc Update_Orders;
   Dcl-DS orders likeDS(orders_ds);

   orders = Parse_With_Data_into();
   Insert_Orders(orders);

 End-Proc; // Update_Orders

 //////////////////////////////////////////////////////////////////
 // Parse_With_Data_Into
 // extracts data from request body and uses PUIUDFINTO parser
 // to parse into a datastructure
 //
 Dcl-Proc Parse_With_Data_Into;
     Dcl-Pi *n likeds(orders_DS);
   End-Pi;

   Dcl-DS ordersDS likeDS(orders_DS);

   clear ordersDS;

   // DATA-INTO using the PUIUDFINTO parser simplifies the process of
   //  retrieving data from the request body
   //  The first parameter in %DATA is usually the document to parse
   //  however PUIUDFINTO automatically uses the request body
   //  allowmissing=yes is needed here because there is an object array
   //  in the data of unknown length which must be mapped to a DS array
   //  with a fixed length
   DATA-INTO ordersDS %DATA('': 'case=convert allowmissing=yes')
                   %PARSER('PUIUDFINTO');
   return ordersDS;

 END-PROC; // Parse_With_Data_Into


 ///////////////////////////////////////////////////////////
 // Insert Order
 //
 Dcl-Proc Insert_Orders;
   Dcl-Pi *n ;
     orders likeds(orders_ds);
   End-Pi;
   Dcl-DS OrderData extname('ORDDTL') qualified End-DS;
   Dcl-S headerId packed(5:0);
   Dcl-S Idx packed(2:0);

   // this line turns off commitment control
   // remvoe if not needed
   exec sql SET OPTION COMMIT = *NONE;

   // create a new Order Header adn return the Id into headerId
   exec sql
     SELECT ohid INTO :headerId
    FROM FINAL TABLE
    (
     INSERT INTO ORDHDR (OHID, OHDATE)
     VALUES (DEFAULT, DEFAULT)
    );
   Check_Sql_Error();

   // insert each order detail record from the orders datastructure
   idx = 1;
   DOW orders.orders(idx).ordtlid > 0;
     eval-corr OrderData = orders.orders(idx);
     OrderData.ORID = headerId;

     exec sql
      Insert into ORDDTL Values(:OrderData);
     Check_Sql_Error();

     // adjust inventory for the quantity of parts ordered
     exec sql
       update ProductsP
         set PRQTY = PRQTY - :OrderData.ORQTY
       where PRID = :OrderData.ORPRID ;
     Check_Sql_Error();

     idx += 1;
   ENDDO;

 End-Proc;

 ///////////////////////////////////////////////////////////
 // Return_Products
 // get product information from the table and write to the display
 //
 Dcl-Proc Return_Products;
   Dcl-DS tableProduct_ds ExtName('PRODUCTSP') QUALIFIED End-DS;

   Dcl-DS displayProduct_ds likeRec(product:*output);

   // start the JSON return object
   Write HEAD;

   exec sql declare c1 cursor for
   select * from productsp;
   Check_Sql_Error();

   exec sql open c1;
   Check_Sql_Error();

   EXEC SQL
     FETCH C1 INTO :tableProduct_ds ;
   Check_Sql_Error();

   Dow SQLCODE = 0;
     clear displayProduct_ds;
     eval-corr displayProduct_ds = tableProduct_ds;

     // write product object to response
     write product displayProduct_ds;

     EXEC SQL
       FETCH C1 INTO :tableProduct_ds ;
     Check_Sql_Error();

   EndDo;
   exec sql close c1;

   //close response data
   Write FOOT;

 End-Proc; //Return_Products

 ///////////////////////////////////////////////////////////
 // Check_Sql_Error
 // checks for an error and writes an error format if there is
 //
 Dcl-Proc Check_Sql_Error;

   if sqlCode < 0;
     write error;
   endif;
 End-Proc;  // Check_Sql_Error;
                                           