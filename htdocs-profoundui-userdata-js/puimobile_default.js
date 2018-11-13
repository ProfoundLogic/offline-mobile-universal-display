/*
 * Example of puimobile_default.js written in Revealing Module Pattern
 *
 * Caution: this example uses HTML localStorage for storing data on the device. This approach is generally reliable, but 
 *   there are cases where data stored this way can be lost. For example, when the device's storage is low, to free space the
 *   operating system may automatically clear data from localStorage.
 *   Additionally, because all connections share the same instance of localStorage, care must be taken between offline
 *   applications to use unique strings for storage keys. Otherwise, for example, if one connection writes to "orders", and
 *   another connection reads from "orders", the second connection would be mixing up data from the first connection.
 * To avoid data loss, the device's local filesystem storage should be used. Alternately, a database saved on the device 
 *   could be used.
 */

// Place all end-user code in `pui.mobile`
pui.mobile = (function () {
  /**
  * Perform sync
  * If any local order data exists, send it to the server, then get back an updated
  * inventory list.
  * @param {object} connection Object containing server URL and port information for this connection.
  * @param {string} connection.name The connection name.
  * @param {string} connection.host The server name or IP address.
  * @param {string} connection.port The port number for this connection.
  * @param {boolean} connection.ssl Use https?
  * @param {string} connection.parm The parameter to use with this connection.
  * @param {string} connection.baseURL A convenience property containing the base URL for this connection, formatted using the above properties (e.g., "https://yourServer:8080").
  * @param {string} connection.syncURL A convenience property containing a formatted `sync` URL (e.g., "https://yourServer:8080/sync?parameter=abc").
  * @param {function} callback Callback function that must be called when the sync process has completed.
  */
  function sync(connection, callback) {
    var config = {
      headers: { "Content-Type": "application/json" },
      url: connection.syncURL,
      method: "post",
      onfail: function (ajaxRequest) {
        callback(ajaxRequest.getStatusMessage());
      },
      handler: syncHandler
    };

    // Retrieve order info from local storage
    var orders = getObject("orders");

    if (orders) {
      config.postData = JSON.stringify({ orders: orders });
    }

    // Send sync request to server
    ajaxJSON(config);

    /**
    * AJAX sync request handler
    */
    function syncHandler(response) {
      // The response will be an updated Products file, so store it to the
      // device and remove the orders that have already been sent.
      if (response.products) {
        storeObject("products", response.products);
        removeObject("orders");
      }
      callback(null);
    }
  }

  /**
  * Retrieve a JavaScript object from device
  */
  function getObject(key) {
    var obj = window.localStorage.getItem(key);

    return JSON.parse(obj);
  }

  /**
  * Store a JavaScript object to device
  */
  function storeObject(key, obj) {
    window.localStorage.setItem(key, JSON.stringify(obj));
  }

  /**
  * Remove a JavaScript object from device
  */
  function removeObject(key) {
    window.localStorage.removeItem(key);
  }

  /**
   * Run the offline app
   * @param {object} displayData JSON data that describes the offline app's display content.
   * @param {object} connection Connection information for this offline app.
   * @param {string} connection.name Descriptive name of the connection.
   * @param {string} connection.host Hostname
   * @param {string} connection.port Port
   * @param {boolean} connection.ssl Use SSL?
   * @param {string} connection.parm Parameter to pass to back end
   * @param {function} callback Callback function that must be called when the run process has completed.
   */
  function run(displayData, connection, callback) {
    // Initialize data
    // Retrieve product data from local storage
    var products = getObject("products") || [];
    var savedOrders = getObject("orders") || [];

    savedOrders.qtyPurchasedForId = function (id) {
      var qty = this.filter(function (e) {
        return e.orprid == id;
      });

      if (qty.length === 0) {
        return 0;
      } else {
        return qty[0].orqty;
      }
    };

    // Update products table with saved order counts
    products.forEach(function (product) {
        product.orqty = savedOrders.qtyPurchasedForId(product.prid);
    })

    // Create config object that will be passed to pui.show()
    var config = {
      meta: displayData,
      format: "Orders",
      data: { ProdGrid: products },
      handler: displayHandler,
      transition: { animation: "slide-left", screen: "new" }
    }

    // Display screen and process user input
    pui.show(config);

    return;


    // Order screen handler -- called when user takes UI action
    function displayHandler(response) {
      console.log(response);

      if (response["exit"] === "1") {
        callback();

        return;
      }
    }
  }

  /**
   * Store shopping cart data when checking out
   * @param {object} data Grid data from grid.getAllDataValues() -- provided by checkout button's Onclick event.
   */
  function checkout(data) {
    var isOrder = function (product) {
      return product.orqty > 0;
    };
    var buildOrders = function (product, index) {
      var order = {};

      order.ordtlid = index+1;
      order.orprid = product.prid;
      order.orqty = product.orqty;
      order.orprice = product.prprice;
      return order;
    };
    var orders = data
      .filter(isOrder)
      .map(buildOrders);

    removeObject("orders");

    if (orders.length > 0) {
      storeObject("orders", orders);
    }
  }

  /**
   * Determine if queued-up data exists that can be synced with the server.
   */
  function isSyncNeeded() {
    var orders = getObject("orders");

    return orders !== null;
  }

  // Return public methods
  return {
    sync: sync,
    run: run,
    isSyncNeeded: isSyncNeeded,
    checkout: checkout
  }
})();
