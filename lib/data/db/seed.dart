import '../models/models.dart';

/// Default categories use fixed IDs and `updatedAt = 0` so the same
/// defaults on two devices merge cleanly, and any real edit always wins.
List<Category> defaultCategories() {
  var order = 0;
  Category exp(String id, String name, String icon, int color, String kw) =>
      Category(
        id: id,
        name: name,
        type: TxnType.expense,
        icon: icon,
        color: color,
        keywords: splitKeywords(kw),
        sortOrder: order++,
      );
  Category inc(String id, String name, String icon, int color, String kw) =>
      Category(
        id: id,
        name: name,
        type: TxnType.income,
        icon: icon,
        color: color,
        keywords: splitKeywords(kw),
        sortOrder: order++,
      );

  return [
    exp('exp_food', 'Food & Dining', 'restaurant', 0xFFFF8A3D,
        'khana,khaana,food,lunch,dinner,breakfast,nashta,nashtay,biryani,pizza,burger,restaurant,hotel,chai,tea,coffee,shawarma,roti,paratha,karahi,samosa,pakora,pakoray,fries,kfc,mcdonalds,bbq,tikka,snacks,snack,biscuit,chips,juice,cold drink,coke,pepsi,ice cream,icecream,mithai,meal,dhaba,foodpanda,sandwich,nihari,haleem,pulao,dahi bhalla,chaat,golgappay,kulfi,cake,bakery,donut'),
    exp('exp_grocery', 'Groceries', 'basket', 0xFF22C55E,
        'grocery,groceries,ration,sabzi,sabziyan,doodh,milk,anda,anday,eggs,egg,atta,aata,chawal,rice,cheeni,sugar,oil,ghee,daal,dal,fruit,fruits,phal,bread,double roti,dahi,yogurt,chicken,murgi,gosht,meat,mutton,beef,qeema,aloo,pyaz,tamatar,namak,masala,mart,karyana,kiryana,utility store,makhan,butter,cheese,pani ki bottle,mineral water,cereal,shahad'),
    exp('exp_fuel', 'Fuel', 'fuel', 0xFFE5484D,
        'petrol,diesel,fuel,cng,octane,hi octane,tanki'),
    exp('exp_transport', 'Transport', 'car', 0xFF3B82F6,
        'uber,careem,indrive,indriver,bykea,yango,rickshaw,rikshaw,riksha,taxi,cab,bus,train,metro,fare,parking,toll,motorway,travel,safar,daewoo'),
    exp('exp_bills', 'Bills & Utilities', 'bill', 0xFF8B5CF6,
        'bill,bills,bijli,electricity,light bill,gas bill,sui gas,gas,pani ka bill,water bill,internet,wifi,ptcl,load,easyload,recharge,mobile package,mobile load,package,kelectric,k electric,lesco,iesco,mepco,fesco,gepco,pesco,cable,lpg,cylinder,netflix bill'),
    exp('exp_shopping', 'Shopping', 'bag', 0xFFEC4899,
        'shopping,kapray,kapre,kapde,kapda,clothes,cloth,shoes,joote,jootay,jutay,shirt,tshirt,pant,jeans,dress,suit,daraz,mall,bag,watch,perfume,jacket,sweater,chappal,sandal,phone,mobile phone,laptop,headphones,earbuds,charger,cover,electronics,amazon,temu'),
    exp('exp_health', 'Health', 'health', 0xFF14B8A6,
        'medicine,medicines,dawai,dawa,dawaai,doctor,hospital,clinic,lab,test,pharmacy,medical,checkup,dentist,injection,surgery,xray,x ray,ultrasound,physio'),
    exp('exp_education', 'Education', 'school', 0xFF6366F1,
        'school,fees,fee,tuition,books,book,kitab,kitaab,kitabain,course,college,university,uni,stationery,copy,copies,academy,exam,coaching'),
    exp('exp_rent', 'Rent', 'home', 0xFFA16207,
        'rent,kiraya,kiraaya,ghar ka kiraya,house rent,flat rent,maintenance charges'),
    exp('exp_entertainment', 'Entertainment', 'movie', 0xFFF59E0B,
        'movie,movies,cinema,film,netflix,spotify,youtube,game,games,gaming,outing,picnic,party,concert,prime,subscription,playland'),
    exp('exp_personal', 'Personal Care', 'spa', 0xFF06B6D4,
        'salon,haircut,hair cut,baal,barber,nai,cosmetics,parlour,parlor,makeup,shampoo,soap,sabun,toothpaste,facewash,cream,lotion,shave'),
    exp('exp_family', 'Family & Gifts', 'gift', 0xFFF43F5E,
        'gift,gifts,tohfa,shaadi,shadi,wedding,birthday,eidi,salami,family,bachon,bachay,ammi,abbu,walima,mehndi'),
    exp('exp_charity', 'Charity', 'charity', 0xFF10B981,
        'sadqa,sadqah,sadaqah,sadka,zakat,zakaat,charity,khairat,khairaat,donation,chanda,fitrana,masjid'),
    exp('exp_vehicle', 'Vehicle', 'build', 0xFF64748B,
        'repair,mechanic,service,oil change,engine oil,mobil oil,tyre,tire,puncture,car wash,bike service,tuning,battery,spare parts,workshop'),
    exp(kOtherExpenseId, 'Other', 'more', 0xFF94A3B8, ''),
    inc('inc_salary', 'Salary', 'salary', 0xFF15A35A,
        'salary,tankhwah,tankhwa,tankha,tankhah,payroll,wages,wage,mahana'),
    inc('inc_business', 'Business', 'store', 0xFF0EA5E9,
        'business,sale,sales,dukaan,dukan,karobar,order,customer'),
    inc('inc_freelance', 'Freelance', 'laptop', 0xFF8B5CF6,
        'freelance,freelancing,upwork,fiverr,project,client,gig,contract'),
    inc('inc_investment', 'Investment', 'trending', 0xFFF59E0B,
        'profit,munafa,dividend,interest,returns,stocks,shares,crypto,savings,mutual fund'),
    inc('inc_gift', 'Gifts Received', 'redeem', 0xFFF43F5E,
        'gift,eidi,salami,tohfa,inaam,reward,shagun'),
    inc('inc_rental', 'Rental Income', 'apartment', 0xFFA16207,
        'kiraya,rent,kiraaya'),
    inc('inc_refund', 'Refunds', 'refund', 0xFF14B8A6,
        'refund,cashback,wapsi,wapas'),
    inc(kOtherIncomeId, 'Other Income', 'more', 0xFF94A3B8, ''),
  ];
}

List<Wallet> defaultWallets() => const [
      Wallet(
        id: kCashWalletId,
        name: 'Cash',
        icon: 'cash',
        color: 0xFF15A35A,
        sortOrder: 0,
      ),
      Wallet(
        id: 'wallet_bank',
        name: 'Bank',
        icon: 'bank',
        color: 0xFF3B82F6,
        sortOrder: 1,
      ),
    ];
