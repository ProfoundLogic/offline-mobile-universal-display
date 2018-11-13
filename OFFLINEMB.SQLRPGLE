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
 Dcl-DS order_ds template;
   ordtlid packed(5);
   orprice packed(7:2);
   orprid packed(5);
   orqty packed(5);
 End-DS;
 Dcl-DS orders_DS qualified template;
   num_orders int(10);
   Dcl-DS orders  likeds(order_ds) dim(50);
 End-DS;



 ///////////////////////////////////////////////////////////
 // Main Procedure
 //

 Dcl-Proc Main;

   clear SqlCode;

   Open OFFLINEMBD;

   Update_Orders();

   Return_Products();

   Close OFFLINEMBD;

 End-Proc;

 // get orders from the request body and update the orders tables
 Dcl-Proc Update_Orders;
   Dcl-DS orders likeDS(orders_ds);
   orders = Parse_Orders();
   Insert_Orders(orders);
 End-Proc;

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

   exec sql SET OPTION COMMIT = *NONE;
   exec sql
     SELECT ohid INTO :headerId
    FROM FINAL TABLE
    (
     INSERT INTO ORDHDR (OHID, OHDATE)
     VALUES (DEFAULT, DEFAULT)
    );

   Check_Sql_Error();
   FOR idx = 1 to orders.num_orders;
     eval-corr OrderData = orders.orders(idx);
     OrderData.ORID = headerId;
     exec sql
      Insert into ORDDTL Values(:OrderData);

     Check_Sql_Error();

     exec sql
       update ProductsP
         set PRQTY = PRQTY - :OrderData.ORQTY
       where PRID = :OrderData.ORPRID ;

     Check_Sql_Error();
   ENDFOR;

 End-Proc;

 ///////////////////////////////////////////////////////////
 // Return_Products
 // get product information from the table and write to the display
 //
 Dcl-Proc Return_Products;
   Dcl-DS tableProduct_ds ExtName('PRODUCTSP') QUALIFIED End-DS;

   Dcl-DS displayProduct_ds likeRec(product:*output);

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
     write product displayProduct_ds;
     EXEC SQL
       FETCH C1 INTO :tableProduct_ds ;

     Check_Sql_Error();
   EndDo;
   exec sql close c1;

   Write FOOT;

 End-Proc; //Return_Products

 ///////////////////////////////////////////////////////////
 //
 //
 //
 Dcl-Proc Check_Sql_Error;

   if sqlCode < 0;
     write error;
   endif;
 End-Proc;  // Check_Sql_Error;

 /////////// JSON parsing procedures ////////////

 ///////////////////////////////////////////////////////////
 // ParseOrders get the raw JSON for the orders from the
 //  request body and then call some procedures to parse the order data
 Dcl-Proc Parse_Orders;
   Dcl-Pi *n likeds(orders_ds);
   End-Pi;
   Dcl-Pr getenv pointer extproc('getenv');
     *n pointer value options(*string:*trim)  ;
   End-Pr;

  Dcl-S REQUEST_METHOD varchar(50);
   Dcl-S CONTENT_TYPE varchar(50);
   Dcl-S JSONLen int(10); // based(p_JSON);
   // CCSID(1208) should be specific in order to convert data
   Dcl-S data char(65000) based(p_JSON) CCSID(1208);
   Dcl-S data2 varchar(65000);
   Dcl-DS return_ds likeDS(orders_ds);
   clear return_ds;

   // Get request method and content type
   REQUEST_METHOD = %str(getenv('REQUEST_METHOD'));
   CONTENT_TYPE = %Str(getenv('CONTENT_TYPE'));

   //if the request is a post containing JSON then continue to parse
   If REQUEST_METHOD = 'POST' and CONTENT_TYPE = 'application/json';
     p_Json = getenv('PUI_UNIVERSAL_INPUT');
     JSONLen = %int(%str(getenv('CONTENT_LENGTH')));
     //gets just the Orders part of the post data
     if JSONLen > 15;
       data2 = %subst(data:12:JSONLen - 13);
       return_ds = orders_split(data2);
     endif;
   ENDIF;

   return return_ds;
 End-Proc;

 // ----- This example uses basic string manipulation to parse a very
 //   specific predetermined JSON string. A more robust solution may
 //   include the use of a JSON parser
 //   A DATA-INTO parser, PUIUDFINTO, is included in PUI Universal Displays
 //   See the documentation site for details
 ///////////////////////////////////////////////////////////
 // Orders_Split split json into individual orders
 // and then call Order_Split to parse out field values
 //
 Dcl-Proc Orders_Split;
   Dcl-Pi *n likeDS(orders_ds);
     source          VarChar(65000)   const;
   End-Pi;
   Dcl-S list VarChar(255) dim(50);
   Dcl-S idx             Zoned(3:0)      Inz(*zeros);
   Dcl-S idx2             Zoned(3:0)      Inz(*zeros);
   Dcl-S ctr             Zoned(3:0)      Inz(*zeros);
   Dcl-DS orders likeDS(orders_ds);
 Dcl-DS myorder;
   ordtlid packed(5);
   orprice packed(7:2);
   orprid packed(5);
   orqty packed(5);
 End-DS;

   idx = 1;
   For ctr = 1 to %len(%trim(source));
     If ctr > %len(%trim(source)) - 2 or
       %trim(%subst(source:ctr:2)) <> ',{';
       list(idx) += %trim(%subst(source:ctr:1));
     Else;
       idx += 1;
       ctr += 1;
     EndIf;
   EndFor;

   for idx2 = 1 to idx;
     orders.orders(idx2) = order_split(list(idx2));
   ENDFOR;
   orders.num_orders = idx;
   return orders;
 End-Proc; //orders_split


 ///////////////////////////////////////////////////////////
 // Order_Split assign individual field values from JSON data
 //
 //
 Dcl-Proc Order_Split;
   Dcl-Pi *n likeDS(order_ds);
     source VarChar(255);
   End-Pi;
   Dcl-DS returnOrder likeds(order_ds);

   returnOrder.ordtlid = get_num_value('ordtlid':source);
   returnOrder.orprice = get_num_value('orprice':source);
   returnOrder.orprid = get_num_value('orprid':source);
   returnOrder.orqty = get_num_value('orqty':source);
   return returnOrder;
 End-Proc; //Order-Split;

 ///////////////////////////////////////////////////////////
 // get_Num_Value gets the value from a simple JSON object based on the name passed in
 // This will work only with a simple object with numeric values
 // If the values were strings it is possiblee the value could have a comma
 Dcl-Proc Get_Num_Value;
   Dcl-Pi *n packed(10:2);
     name_i varChar(255) const;
     source varChar(255) ;
   End-Pi;

   //local definitions
   Dcl-S numresult packed(10:2);
   Dcl-S charresult varChar(255);
   Dcl-S name varChar(255);

   clear numresult;
   //add double quotes to name for search
   name = '"' + name_i + '"';

   //find the value which will be everything between the colon after the name
   // to the next comma. Replaced } with a comma so the last value will be followed by comma
   charresult =
     %subst(source:%scan(name:source) + %len(name) + 1 :
      (%scan(',':%xlate('}':',':source):%scan(name:source) + %len(name) + 1))
         -  (%scan(name:source) + %len(name) + 1) );

   // Check to make sure the result is a number
   if charresult > '' and %check(' 0123456789.':charresult) = 0;
     numresult = %dec(charresult:10:2);
   ENDIF;
   return numresult;

End-Proc;//get_num_vlue                                           