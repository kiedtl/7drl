const std = @import("std");
const math = std.math;

const state = @import("state.zig");
usingnamespace @import("types.zig");

var sintable: [360]f64 = [360]f64{ 0.0, 0.8414709848078965, 0.9092974268256817, 0.1411200080598672, -0.7568024953079282, -0.9589242746631385, -0.27941549819892586, 0.6569865987187891, 0.9893582466233818, 0.4121184852417566, -0.5440211108893698, -0.9999902065507035, -0.5365729180004349, 0.4201670368266409, 0.9906073556948704, 0.6502878401571168, -0.2879033166650653, -0.9613974918795568, -0.750987246771676, 0.14987720966295234, 0.9129452507276277, 0.8366556385360561, -0.008851309290403876, -0.8462204041751706, -0.9055783620066239, -0.13235175009777303, 0.7625584504796027, 0.956375928404503, 0.27090578830786904, -0.6636338842129675, -0.9880316240928618, -0.404037645323065, 0.5514266812416906, 0.9999118601072672, 0.5290826861200238, -0.428182669496151, -0.9917788534431158, -0.6435381333569995, 0.2963685787093853, 0.9637953862840878, 0.7451131604793488, -0.158622668804709, -0.9165215479156338, -0.8317747426285983, 0.017701925105413577, 0.8509035245341184, 0.9017883476488092, 0.123573122745224, -0.7682546613236668, -0.9537526527594719, -0.26237485370392877, 0.6702291758433747, 0.9866275920404853, 0.39592515018183416, -0.5587890488516163, -0.9997551733586199, -0.5215510020869119, 0.43616475524782494, 0.9928726480845371, 0.6367380071391379, -0.3048106211022167, -0.9661177700083929, -0.7391806966492228, 0.16735570030280691, 0.9200260381967906, 0.8268286794901034, -0.026551154023966794, -0.8555199789753223, -0.8979276806892913, -0.11478481378318722, 0.7738906815578891, 0.9510546532543747, 0.25382336276203626, -0.6767719568873076, -0.9851462604682474, -0.38778163540943045, 0.5661076368981803, 0.9995201585807313, 0.5139784559875352, -0.4441126687075084, -0.9938886539233752, -0.6298879942744539, 0.31322878243308516, 0.9683644611001854, 0.7331903200732922, -0.1760756199485871, -0.9234584470040598, -0.8218178366308225, 0.03539830273366068, 0.8600694058124533, 0.8939966636005579, 0.10598751175115685, -0.7794660696158047, -0.9482821412699473, -0.24525198546765434, 0.683261714736121, 0.9835877454343449, 0.3796077390275217, -0.5733818719904229, -0.9992068341863537, -0.5063656411097588, 0.45202578717835057, 0.9948267913584063, 0.6229886314423488, -0.32162240316253093, -0.9705352835374847, -0.7271425000808526, 0.18478174456066745, 0.926818505417785, 0.8167426066363169, -0.044242678085070965, -0.8645514486106083, -0.8899956043668333, -0.09718190589320902, 0.7849803886813105, 0.9454353340247703, 0.23666139336428604, -0.689697940935389, -0.9819521690440836, -0.3714041014380902, 0.5806111842123143, 0.9988152247235795, 0.4987131538963941, -0.45990349068959124, -0.9956869868891794, -0.6160404591886565, 0.329990825673782, 0.972630067242408, 0.7210377105017316, -0.19347339203846847, -0.9301059501867618, -0.8116033871367004, 0.05308358714605824, 0.8689657562142357, 0.8859248164599484, 0.08836868610400143, -0.7904332067228887, -0.9425144545582509, -0.2280522595008612, 0.6960801312247415, 0.9802396594403116, 0.363171365373259, -0.5877950071674065, -0.9983453608739179, -0.49102159389846933, 0.4677451620451334, 0.9964691731217737, 0.6090440218832924, -0.3383333943242765, -0.9746486480944947, -0.7148764296291646, 0.20214988141565363, 0.933320523748862, 0.8064005807754863, -0.06192033725605731, -0.8733119827746476, -0.8817846188147811, -0.0795485428747221, 0.7958240965274552, 0.9395197317131483, 0.21942525837900473, -0.702407785577371, -0.9784503507933796, -0.35491017584493534, 0.5949327780232085, 0.9977972794498907, 0.48329156372825655, -0.47555018687189876, -0.9971732887740798, -0.6019998676776046, 0.3466494554970303, 0.9765908679435658, 0.7086591401823227, -0.2108105329134813, -0.9364619742512132, -0.8011345951780408, 0.07075223608034517, 0.8775897877771157, 0.8775753358042688, 0.07072216723899125, -0.8011526357338304, -0.936451400117644, -0.21078106590019152, 0.7086804082392084, 0.9765843832906294, 0.346621180094276, -0.6020239375552833, -0.997171023392149, -0.47552366901205834, 0.48331795366796265, 0.9977992786806003, 0.594908548461427, -0.3549383576518463, -0.9784565746221131, -0.7023863292684921, 0.21945466799406363, 0.9395300555699313, 0.7958058429196471, -0.07957859166428352, -0.8817988360675502, -0.8732972972139946, -0.06189025071872073, 0.8064184068658303, 0.9333097001669604, 0.2021203593127912, -0.7148975077677643, -0.97464190312541, -0.3383050275409778, 0.6090679301910603, 0.9964666417661079, 0.46771851834275896, -0.491047853850463, -0.9983470937967718, -0.5877706198198406, 0.36319945137636067, 0.9802456219572225, 0.6960584883449115, -0.22808160941352784, -0.9425245273294025, -0.7904147414931815, 0.08839871248753149, 0.8859387978787574, 0.8689508382163493, 0.05305348526993529, -0.8116209973649744, -0.9300948780045254, -0.19344381715900788, 0.7210585970706318, 0.9726230624856244, 0.3299623697323973, -0.6160642040533645, -0.9956841897581032, -0.4598767232321427, 0.49873928180328125, 0.9988166912028082, 0.5805866409896447, -0.37143208943692263, -0.9819578697820255, -0.6896761131802671, 0.2366906812750767, 0.9454451549211168, 0.7849617132764033, -0.09721190751822432, -0.8900093488562771, -0.8645362993442719, -0.04421256322855966, 0.8167599996228085, 0.9268071855026884, 0.184752119221718, -0.727163193443649, -0.9705280195418053, -0.3215938602925038, 0.623012211003653, 0.9948237286710673, 0.45199889806298343, -0.5063916349244909, -0.9992080341070627, -0.5733571748155426, 0.37963562682930313, 0.9835931839466808, 0.6832397038158508, -0.24528120908194284, -0.9482917095220488, -0.7794471854988634, 0.10601748626711377, 0.8940101700837942, 0.8600540264645697, 0.035368177256176046, -0.8218350110128397, -0.9234468802429867, -0.1760459464712114, 0.7332108186087175, 0.9683569384347241, 0.3132001548706699, -0.6299114066849614, -0.9938853259197261, -0.4440856600409099, 0.5140043136735694, 0.99952109184891, 0.5660827877060441, -0.3878094208292295, -0.9851514363288851, -0.6767497645263835, 0.253852519790234, 0.9510639681125854, 0.7738715902084317, -0.11481475884166603, -0.8979409481081247, -0.8555043707508208, -0.026521020285755953, 0.8268456339220814, 0.9200142254959646, 0.16732598101183924, -0.739200998751274, -0.9661099892625297, -0.30478191109030295, 0.6367612505645516, 0.992869055025318, 0.43613762914604876, -0.5215767216183704, -0.9997558399011495, -0.5587640495890891, 0.39595283104274065, 0.9866325048439105, 0.6702068037805061, -0.2624039418616639, -0.9537617134939987, -0.7682353642374472, 0.12360303600011291, 0.9018013749637745, 0.8508876886558596, 0.01767178546737087, -0.8317914757822045, -0.9165094902005468, -0.15859290602857282, 0.7451332645574127, 0.9637873480674221, 0.2963397884973224, -0.6435612059762619, -0.9917749956098326, -0.42815542808445156, 0.5291082654818533, 0.9999122598719259, 0.551401533867395, -0.4040652194563607, -0.9880362734541701, -0.6636113342009432, 0.2709348053161655, 0.9563847343054627, 0.7625389491684939, -0.13238162920545193, -0.9055911481970673, -0.8462043418838514, -0.008821166113885877, 0.8366721491002946, 0.9129329489429682, 0.14984740573347818, -0.7510071512506543, -0.9613891968218607, -0.2878744485084861, 0.6503107401625525, 0.9906032333897737, 0.4201396822393068, -0.5365983551885637, -0.9999903395061709, -0.5439958173735323, 0.412145950487085, 0.9893626321783087, 0.6569638725243397, -0.27944444178438205, -0.9589328250406132, -0.7567827912998033, 0.14114985067939137, 0.9093099708898409, 0.8414546973619527, -3.014435335948845e-05, -0.8414872714892108, -0.9092848819352602, -0.14109016531210986, 0.7568221986283603 };
var costable: [360]f64 = [360]f64{ 1.0, 0.5403023058681398, -0.4161468365471424, -0.9899924966004454, -0.6536436208636119, 0.28366218546322625, 0.960170286650366, 0.7539022543433046, -0.14550003380861354, -0.9111302618846769, -0.8390715290764524, 0.004425697988050785, 0.8438539587324921, 0.9074467814501962, 0.1367372182078336, -0.7596879128588213, -0.9576594803233847, -0.27516333805159693, 0.6603167082440802, 0.9887046181866692, 0.40808206181339196, -0.5477292602242684, -0.9999608263946371, -0.5328330203333975, 0.424179007336997, 0.9912028118634736, 0.6469193223286404, -0.2921388087338362, -0.9626058663135666, -0.7480575296890003, 0.15425144988758405, 0.9147423578045313, 0.8342233605065102, -0.013276747223059479, -0.8485702747846052, -0.9036922050915067, -0.12796368962740468, 0.7654140519453434, 0.9550736440472949, 0.26664293235993725, -0.6669380616522619, -0.9873392775238264, -0.39998531498835127, 0.5551133015206257, 0.9998433086476912, 0.5253219888177297, -0.4321779448847783, -0.9923354691509287, -0.6401443394691997, 0.3005925437436371, 0.9649660284921133, 0.7421541968137826, -0.16299078079570548, -0.9182827862121189, -0.8293098328631502, 0.022126756261955736, 0.8532201077225842, 0.8998668269691937, 0.11918013544881928, -0.7710802229758452, -0.9524129804151563, -0.25810163593826746, 0.6735071623235862, 0.9858965815825497, 0.39185723042955, -0.562453851238172, -0.99964745596635, -0.5177697997895051, 0.4401430224960407, 0.9933903797222716, 0.6333192030862999, -0.3090227281660707, -0.9672505882738824, -0.7361927182273159, 0.17171734183077755, 0.9217512697247493, 0.8243313311075577, -0.03097503173121646, -0.8578030932449878, -0.8959709467909631, -0.11038724383904756, 0.7766859820216312, 0.9496776978825432, 0.24954011797333814, -0.6800234955873388, -0.9843766433940419, -0.38369844494974187, 0.569750334265312, 0.9993732836951247, 0.5101770449416689, -0.4480736161291701, -0.9943674609282015, -0.626444447910339, 0.31742870151970165, 0.9694593666699876, 0.7301735609948197, -0.18043044929108396, -0.9251475365964139, -0.8192882452914593, 0.0398208803931389, 0.8623188722876839, 0.8920048697881602, 0.10158570369662134, -0.7822308898871159, -0.9468680107512125, -0.24095904923620143, 0.6864865509069841, 0.9827795820412206, 0.3755095977670121, -0.577002178942952, -0.999020813314648, -0.5025443191453852, 0.4559691044442761, 0.9952666362171313, 0.6195206125592099, -0.3258098052199642, -0.9715921906288022, -0.7240971967004738, 0.1891294205289584, 0.9284713207390763, 0.8141809705265618, -0.04866360920015389, -0.8667670910519801, -0.8879689066918555, -0.09277620459766088, 0.7877145121442345, 0.9439841391523142, 0.23235910202965793, -0.6928958219201651, -0.9811055226493881, -0.3672913304546965, 0.5842088171092893, 0.9985900724399912, 0.4948722204034305, -0.4638288688518717, -0.9960878351411849, -0.6125482394960996, 0.33416538263076073, 0.9736488930495181, 0.717964101410472, -0.19781357400426822, -0.9317223617435201, -0.8090099069535975, 0.05750252534912421, 0.8711474010323434, 0.8838633737085002, 0.08395943674184847, -0.7931364191664784, -0.9410263090291437, -0.22374095013558368, 0.6992508064783751, 0.9793545963764285, 0.35904428689111606, -0.5913696841443247, -0.9980810948185003, -0.48716134980334147, 0.47165229356133864, 0.9968309933617175, 0.6055278749869898, -0.34249477911590703, -0.9756293127952373, -0.7117747556357236, 0.20648222933781113, 0.9349004048997503, 0.803775459710974, -0.06633693633562374, -0.875459459043705, -0.8796885924951523, -0.07513609089835323, 0.7984961861625556, 0.9379947521194415, 0.21510526876214117, -0.7055510066862999, -0.9775269404025313, -0.3507691132091307, 0.5984842190140996, 0.9974939203271522, 0.47941231147032193, -0.4794387656291727, -0.9974960526543551, -0.5984600690578581, 0.3507973420904214, 0.9775332947055968, 0.705529644294206, -0.21513470736462095, -0.9380052012169503, -0.7984780389030324, 0.07516615000819327, 0.879702927248347, 0.8754448901342752, 0.06630685835171127, -0.8037933932096717, -0.9348897059372352, -0.20645273449087873, 0.711795928940826, 0.9756226979194443, 0.3424664577455166, -0.6055518643146514, -0.9968285949694307, -0.47162571251991114, 0.4871876750070059, 0.9980829609135574, 0.591345375451585, -0.35907242107165305, -0.9793606896089245, -0.6992292566729736, 0.22377033018717848, 0.9410365074429887, 0.7931180595679168, -0.08398947462256867, -0.8838774731823718, -0.8711325991081119, -0.057472430847665464, 0.8090276252864301, 0.9317114137542325, 0.19778402522372224, -0.7179850839697136, -0.9736420181192547, -0.33413697099017103, 0.6125720663156844, 0.9960851708717215, 0.4638021630104179, -0.49489841458940237, -0.9985916721566993, -0.5841843515845697, 0.36731936773024515, 0.9811113543339269, 0.6928740863898232, -0.23238842122852268, -0.9439940860834779, -0.787695941645058, 0.09280621889587708, 0.8879827697817494, 0.8667520572726362, 0.048633500538969116, -0.8141984723053474, -0.9284601245807608, -0.18909982012986337, 0.7241179868699296, 0.9715850561826999, 0.32578130553514806, -0.6195442750039529, -0.9952637062792294, -0.4559422758951242, 0.5025703802614231, 0.9990221465276736, 0.5769775585030581, -0.3755375359409301, -0.982785151720906, -0.68646463135462, 0.24098830528525864, 0.9468777054203809, 0.7822121099422712, -0.10161569206079699, -0.892018495407942, -0.8623036078310824, -0.03979075993115771, 0.8193055291449822, 0.9251360931462582, 0.18040079959254857, -0.7301941571456378, -0.9694519732670104, -0.31740011602352985, 0.6264679441263539, 0.9943642655514137, 0.44804666697426215, -0.510202970945957, -0.9993743503000143, -0.5697255608391865, 0.3837262818331512, 0.9843819506325049, 0.6800013937302882, -0.24956930858045798, -0.9496871395301657, -0.7766669941024745, 0.11041720391967796, 0.8959843338731037, 0.8577875993070563, 0.030944901828293042, -0.8243483956816764, -0.9217395798793158, -0.17168764515577298, 0.7362131187458456, 0.9672429364932829, 0.3089940590981371, -0.6333425312327234, -0.9933869191569467, -0.4401159548467677, 0.5177955886508133, 0.9996482558795381, 0.5624289267667438, -0.3918849638415085, -0.9859016259639831, -0.6734848798934681, 0.2581307588164473, 0.9524221683015063, 0.7710610285700272, -0.11921006489861569, -0.8998799744648526, -0.8532043855172293, -0.022096619278683942, 0.8293266768209027, 0.9182708508872743, 0.1629610394708834, -0.7421744001016999, -0.9649581189333869, -0.3005637933500832, 0.6401674977183369, 0.9923317436681922, 0.43215076086181514, -0.5253476385155728, -0.9998438418065069, -0.5550882279566577, 0.4000129427560235, 0.987344058653017, 0.6669156003948422, -0.2666719852274808, -0.955082577452527, -0.7653946525566921, 0.12799358610147818, 0.903705111970614, 0.8485543255436181, 0.01324660552058789, -0.8342399825282196, -0.9147301779353751, -0.15422166624309427, 0.7480775341634341, 0.9625976995964054, 0.2921099792671752, -0.6469423088661069, -0.9911988217552068, -0.424151709070136, 0.5328585288581931, 0.9999610927573088, 0.5477040395322043, -0.40810958177221934, -0.9887091356890289, -0.660294069919136, 0.2751923186322931, 0.9576681585475916, 0.7596683100072248, -0.13676707936387883, -0.907459446701534, -0.8438377837054513, -0.004395553927897717, 0.8390879278598296, 0.911117838425468, 0.14547021017792156, -0.7539220584369601, -0.9601618634146094, -0.28363327918216646, 0.6536664338884767, 0.9899882421792622, 0.4161194261751267, -0.540327671221366, -0.999999999545659, -0.5402769400239504, 0.4161742465410129, 0.9899967501220404, 0.6536208072447929 };

pub fn raycast(center: Coord, radius: usize, limit: Coord, opacity: fn (Coord) f64, buf: *AnnotatedCoordArrayList) void {
    const limitx = @intToFloat(f64, limit.x);
    const limity = @intToFloat(f64, limit.y);

    buf.append(.{ .coord = center, .value = 0 }) catch unreachable;

    var i: usize = 0;
    while (i < 360) : (i += 1) {
        const ax: f64 = sintable[i];
        const ay: f64 = costable[i];

        var x = @intToFloat(f64, center.x);
        var y = @intToFloat(f64, center.y);

        var cumulative_opacity: f64 = 0;
        var z: usize = 0;
        while (z < radius) : (z += 1) {
            x += ax;
            y += ay;

            if (x < 0 or y < 0)
                break;

            const ix = @floatToInt(usize, math.round(x));
            const iy = @floatToInt(usize, math.round(y));
            const coord = Coord.new2(center.z, ix, iy);

            if (ix >= limit.x or iy >= limit.y)
                break;

            const v = @floatToInt(usize, cumulative_opacity * 100);
            buf.append(.{ .coord = coord, .value = v }) catch unreachable;

            cumulative_opacity += opacity(coord);
            if (cumulative_opacity >= 1.0) break;
        }
    }
}

pub fn octants(d: Direction, wide: bool) [8]?usize {
    return if (wide) switch (d) {
        .North => [_]?usize{ 1, 0, 3, 2, null, null, null, null },
        .South => [_]?usize{ 6, 7, 4, 5, null, null, null, null },
        .East => [_]?usize{ 3, 2, 5, 4, null, null, null, null },
        .West => [_]?usize{ 0, 1, 6, 7, null, null, null, null },
        .NorthEast => [_]?usize{ 0, 3, 2, 5, null, null, null, null },
        .NorthWest => [_]?usize{ 3, 0, 1, 6, null, null, null, null },
        .SouthEast => [_]?usize{ 2, 5, 4, 7, null, null, null, null },
        .SouthWest => [_]?usize{ 1, 6, 7, 4, null, null, null, null },
    } else switch (d) {
        .North => [_]?usize{ 0, 3, null, null, null, null, null, null },
        .South => [_]?usize{ 7, 4, null, null, null, null, null, null },
        .East => [_]?usize{ 2, 5, null, null, null, null, null, null },
        .West => [_]?usize{ 1, 6, null, null, null, null, null, null },
        .NorthEast => [_]?usize{ 3, 2, null, null, null, null, null, null },
        .NorthWest => [_]?usize{ 1, 0, null, null, null, null, null, null },
        .SouthEast => [_]?usize{ 5, 4, null, null, null, null, null, null },
        .SouthWest => [_]?usize{ 6, 7, null, null, null, null, null, null },
    };
}

// Ported from doryen-fov Rust crate
// TODO: provide link here
pub fn shadowcast(coord: Coord, octs: [8]?usize, radius: usize, limit: Coord, tile_opacity: fn (Coord) f64, buf: *CoordArrayList) void {
    // Area of coverage by each octant (the MULT constant does the job of
    // converting between octants, I think?):
    //
    //                               North
    //                                 |
    //                            \0000|3333/
    //                            1\000|333/2
    //                            11\00|33/22
    //                            111\0|3/222
    //                            1111\|/2222
    //                       West -----@------ East
    //                            6666/|\5555
    //                            666/7|4\555
    //                            66/77|44\55
    //                            6/777|444\5
    //                            /7777|4444\
    //                                 |
    //                               South
    //
    // Don't ask me how the octants were all displaced from what should've been
    // their positions, I inherited(?) this problem from the doryen-fov Rust
    // crate, from which this shadowcasting code was ported.
    //
    const MULT = [4][8]isize{
        [_]isize{ 1, 0, 0, -1, -1, 0, 0, 1 },
        [_]isize{ 0, 1, -1, 0, 0, -1, 1, 0 },
        [_]isize{ 0, 1, 1, 0, 0, -1, -1, 0 },
        [_]isize{ 1, 0, 0, 1, -1, 0, 0, -1 },
    };

    var max_radius = radius;
    if (max_radius == 0) {
        const max_radius_x = math.max(limit.x - coord.x, coord.x);
        const max_radius_y = math.max(limit.y - coord.y, coord.y);
        max_radius = @floatToInt(usize, math.sqrt(@intToFloat(f64, max_radius_x * max_radius_x + max_radius_y * max_radius_y))) + 1;
    }

    for (octs) |maybe_oct| {
        if (maybe_oct) |oct| {
            _cast_light(coord.z, @intCast(isize, coord.x), @intCast(isize, coord.y), 1, 1.0, 0.0, @intCast(isize, max_radius), MULT[0][oct], MULT[1][oct], MULT[2][oct], MULT[3][oct], limit, buf, tile_opacity);
        }
    }

    buf.append(coord) catch unreachable;
}

fn _cast_light(level: usize, cx: isize, cy: isize, row: isize, start_p: f64, end: f64, radius: isize, xx: isize, xy: isize, yx: isize, yy: isize, limit: Coord, buf: *CoordArrayList, tile_opacity: fn (Coord) f64) void {
    if (start_p < end) {
        return;
    }

    var start = start_p;
    var new_start: f64 = 0.0;

    var j: isize = row;
    var stepj: isize = if (row < radius) 1 else -1;

    while (j < radius) : (j += stepj) {
        const dy = -j;
        var dx = -j - 1;
        var blocked = false;
        var pblocked = false;

        while (dx <= 0) {
            dx += 1;

            const cur_x = cx + dx * xx + dy * xy;
            const cur_y = cy + dx * yx + dy * yy;

            if (cur_x < 0 or cur_x >= @intCast(isize, limit.x) or cur_y < 0 or cur_y >= @intCast(isize, limit.y)) {
                continue;
            }

            const coord = Coord.new2(level, @intCast(usize, cur_x), @intCast(usize, cur_y));
            const l_slope = (@intToFloat(f64, dx) - 0.5) / (@intToFloat(f64, dy) + 0.5);
            const r_slope = (@intToFloat(f64, dx) + 0.5) / (@intToFloat(f64, dy) - 0.5);

            if (start < r_slope) {
                continue;
            } else if (end > l_slope) {
                break;
            }

            if (dx * dx + dy * dy <= @intCast(isize, radius * radius)) {
                // Our light beam is hitting this tile, light it.
                buf.append(coord) catch unreachable;
            }

            const op = tile_opacity(coord);

            if (blocked) {
                if (op >= 1.0) {
                    // We're scanning a blocked row.
                    new_start = r_slope;
                    continue;
                } else {
                    blocked = false;
                    start = new_start;
                }
            } else if (op >= 1.0 and j < radius) {
                // This is a blocking square, start a child scan.
                blocked = true;
                _cast_light(level, cx, cy, j + 1, start, l_slope, radius, xx, xy, yx, yy, limit, buf, tile_opacity);
                new_start = r_slope;
            }
        }

        // We've scanned the row.
        // Do next row unless last square was blocking.
        if (blocked) {
            break;
        }
    }
}
